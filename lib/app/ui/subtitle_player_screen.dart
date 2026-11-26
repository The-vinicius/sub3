import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:sub3/app/services/anki_service.dart';
import 'package:sub3/app/services/gguf_model_service.dart';
import 'package:sub3/app/services/translation_service.dart';
import 'package:sub3/app/ui/widgets/word_tappable_text.dart';

class Subtitle {
  final Duration start;
  final Duration end;
  final String text;
  Subtitle(this.start, this.end, this.text);
}

class SubtitlePlayerScreen extends StatefulWidget {
  final File subtitleFile;
  final File audioFile;
  const SubtitlePlayerScreen({
    super.key,
    required this.subtitleFile,
    required this.audioFile,
  });
  @override
  State<SubtitlePlayerScreen> createState() => _SubtitlePlayerScreenState();
}

class _SubtitlePlayerScreenState extends State<SubtitlePlayerScreen> {
  final AudioPlayer player = AudioPlayer();
  final TranslationService _translationService = TranslationService.instance;
  late StreamSubscription<Duration> posSub;
  late StreamSubscription<PlayerState> stateSub;

  final List<Subtitle> subtitles = [];
  final ItemScrollController scrollCtrl = ItemScrollController();

  TargetLanguage _selectedLanguage =
      TranslationService.supportedLanguages.first;
  final Set<String> _translationInFlight = {};
  final Set<String> _ankiInFlight = {};
  final Map<String, String> _streamingTranslations = {};

  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  PlayerState playerState = PlayerState.completed;
  int currentIndex = 0;
  bool sync = true;
  double syncOffsetSeconds = 0.0;

  @override
  void initState() {
    super.initState();
    GgufModelService.instance.refresh();
    _loadSubtitles();
    player.setSource(DeviceFileSource(widget.audioFile.path)).then((_) async {
      duration = await player.getDuration() ?? Duration.zero;
      setState(() {});
    });
    posSub = player.onPositionChanged.listen((p) {
      position = p;
      if (sync) _updateSubtitle(p);
      setState(() {});
    });
    stateSub = player.onPlayerStateChanged.listen((s) {
      playerState = s;
      setState(() {});
    });
  }

  @override
  void dispose() {
    posSub.cancel();
    stateSub.cancel();
    player.dispose();
    super.dispose();
  }

  void _loadSubtitles() {
    final lines = widget.subtitleFile.readAsLinesSync();
    final regex = RegExp(
      r"(\d{2}:\d{2}:\d{2}[,\.]\d{3}) --> (\d{2}:\d{2}:\d{2}[,\.]\d{3})",
    );
    for (int i = 0; i < lines.length; i++) {
      final m = regex.firstMatch(lines[i]);
      if (m != null) {
        Duration parse(String s) {
          final parts = s.split(RegExp(r'[\,:\.]')).map(int.parse).toList();
          return Duration(
            hours: parts[0],
            minutes: parts[1],
            seconds: parts[2],
            milliseconds: parts[3],
          );
        }

        final start = parse(m.group(1)!);
        final end = parse(m.group(2)!);
        i++;
        final buf = StringBuffer();
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          buf.writeln(lines[i]);
          i++;
        }
        subtitles.add(Subtitle(start, end, buf.toString().trim()));
      }
    }
    setState(() {});
  }

  void _adjustSyncOffset(double delta) {
    setState(() {
      syncOffsetSeconds += delta;
      syncOffsetSeconds = (syncOffsetSeconds * 10).roundToDouble() / 10;
      if (sync) _updateSubtitle(position);
    });
  }

  void _updateSubtitle(Duration p) {
    final offset = Duration(milliseconds: (syncOffsetSeconds * 1000).round());
    for (int i = 0; i < subtitles.length; i++) {
      final start = subtitles[i].start + offset;
      final end = subtitles[i].end + offset;
      if (p >= start && p <= end) {
        if (currentIndex != i) {
          currentIndex = i;
          scrollCtrl.scrollTo(
            index: i,
            duration: const Duration(milliseconds: 200),
            alignment: 0.5,
          );
        }
        break;
      }
    }
  }

  static const int _ctxLines = 3;
  static const Duration _ctxMaxGap = Duration(seconds: 8);
  // Japonês omite sujeito com frequência: a próxima linha ajuda a resolver.
  static const bool _ctxIncludeNextForJa = true;
  static const Duration _ctxNextMaxGap = Duration(seconds: 4);
  static final RegExp _kanaRe = RegExp(r'[\u3040-\u30ff]');

  String _cueText(int i) => TranslationService.cleanSubtitle(subtitles[i].text);

  /// Últimas linhas ORIGINAIS antes do cue, parando em pausas longas
  /// (mudança de cena). Para cues em japonês, acrescenta também a próxima.
  List<String> _contextFor(int index) {
    final out = <String>[];
    for (var j = index - 1; j >= 0 && out.length < _ctxLines; j--) {
      if (subtitles[j + 1].start - subtitles[j].end > _ctxMaxGap) break;
      final t = _cueText(j).replaceAll('\n', ' ').trim();
      if (t.isNotEmpty) out.insert(0, t);
    }

    if (_ctxIncludeNextForJa &&
        index + 1 < subtitles.length &&
        _kanaRe.hasMatch(_cueText(index)) &&
        subtitles[index + 1].start - subtitles[index].end <= _ctxNextMaxGap) {
      final next = _cueText(index + 1).replaceAll('\n', ' ').trim();
      if (next.isNotEmpty) out.add(next);
    }
    return out;
  }

  void _togglePlay() {
    if (playerState == PlayerState.playing) {
      player.pause();
    } else {
      player.resume();
    }
  }

  Future<void> _translateCue(int index) async {
    final text = _cueText(index);
    if (text.isEmpty) return;
    final ctx = _contextFor(index);
    final inFlightKey = '${_selectedLanguage.code}:$index';
    if (_translationInFlight.contains(inFlightKey)) return;

    setState(() => _translationInFlight.add(inFlightKey));
    try {
      await for (final partial in _translationService.translateStream(
        text: text,
        targetLanguage: _selectedLanguage,
        context: ctx,
      )) {
        if (!mounted) return;
        setState(() => _streamingTranslations[inFlightKey] = partial);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro na tradução (${_selectedLanguage.name}): $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _translationInFlight.remove(inFlightKey);
          _streamingTranslations.remove(inFlightKey);
        });
      } else {
        _translationInFlight.remove(inFlightKey);
        _streamingTranslations.remove(inFlightKey);
      }
    }
  }

  Future<void> _sendCueToAnki(Subtitle s, int index) async {
    final key = '${s.start.inMilliseconds}:${s.text.trim()}';
    if (_ankiInFlight.contains(key)) return;

    setState(() => _ankiInFlight.add(key));
    try {
      final offset = Duration(milliseconds: (syncOffsetSeconds * 1000).round());
      var start = s.start + offset;
      var end = s.end + offset;
      if (start < Duration.zero) start = Duration.zero;
      if (end <= start) {
        throw StateError('Intervalo de áudio inválido para este subtítulo.');
      }

      final cueText = s.text.trim(); // vai no cartão, como antes
      final text = _cueText(index); // vai para o modelo
      final ctx = _contextFor(index);
      var translation = _translationService.getCachedTranslation(
        _selectedLanguage.code,
        text,
        context: ctx,
      );
      if (translation == null || translation.isEmpty) {
        try {
          translation = await _translationService.translate(
            text: text,
            targetLanguage: _selectedLanguage,
            context: ctx,
          );
        } catch (_) {
          translation = null;
        }
      }

      await AnkiService.instance.sendCue(
        audioFile: widget.audioFile,
        start: start,
        end: end,
        sentence: cueText,
        translation: translation,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cartão enviado para o baralho ${AnkiService.deckName}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível enviar para o Anki: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _ankiInFlight.remove(key));
      } else {
        _ankiInFlight.remove(key);
      }
    }
  }

  void _showCustomModelDialog() {
    final controller = TextEditingController(text: "maternion/hy-mt2:1.8b");
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Modelo personalizado'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nome do Modelo',
                hintText: 'Ex: gpt-4o, gpt-4-turbo, o3-mini...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final newModel = controller.text.trim();
                  if (newModel.isNotEmpty) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Modelo alterado para: $newModel'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player'),
        actions: [
          // Model selection button
          PopupMenuButton<String>(
            tooltip: 'Selecionar modelo OpenAI',
            initialValue: "maternion/hy-mt2:1.8b",
            onSelected: (String model) {
              if (model == '__custom__') {
                _showCustomModelDialog();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Modelo alterado para: $model'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              final items = <PopupMenuEntry<String>>[];
              for (final m in []) {
                final isSelected = m.id == "maternion/hy-mt2:1.8b";
                items.add(
                  PopupMenuItem<String>(
                    value: m.id,
                    child: Row(
                      children: [
                        Icon(
                          Icons.smart_toy_outlined,
                          size: 20,
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.name,
                                style: TextStyle(
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : null,
                                ),
                              ),
                              Text(
                                m.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                );
              }
              items.add(const PopupMenuDivider());
              items.add(
                const PopupMenuItem<String>(
                  value: '__custom__',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Outro modelo personalizado...'),
                    ],
                  ),
                ),
              );
              return items;
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.smart_toy_outlined, size: 16),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      "maternion/hy-mt2:1.8b",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16),
                ],
              ),
            ),
          ),

          // Language selection button
          PopupMenuButton<TargetLanguage>(
            tooltip: 'Selecionar idioma de tradução',
            initialValue: _selectedLanguage,
            onSelected: (TargetLanguage lang) {
              setState(() {
                _selectedLanguage = lang;
              });
            },
            itemBuilder: (BuildContext context) {
              return TranslationService.supportedLanguages.map((lang) {
                final isSelected = lang.code == _selectedLanguage.code;
                return PopupMenuItem<TargetLanguage>(
                  value: lang,
                  child: Row(
                    children: [
                      Text(lang.flag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${lang.name} (${lang.nativeName})',
                          style: TextStyle(
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                );
              }).toList();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedLanguage.flag,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedLanguage.code.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Slider(
                    min: 0,
                    max: duration.inMilliseconds.toDouble(),
                    value:
                        position.inMilliseconds
                            .clamp(0, duration.inMilliseconds)
                            .toDouble(),
                    onChanged:
                        (v) => player.seek(Duration(milliseconds: v.toInt())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(_fmt(position)), Text(_fmt(duration))],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        onPressed:
                            () => player.seek(
                              position - const Duration(seconds: 10),
                            ),
                      ),
                      IconButton(
                        iconSize: 48,
                        icon: Icon(
                          playerState == PlayerState.playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                        ),
                        onPressed: _togglePlay,
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        onPressed:
                            () => player.seek(
                              position + const Duration(seconds: 10),
                            ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Text('Sync'),
                          Switch(
                            value: sync,
                            onChanged: (v) => setState(() => sync = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Ajuste:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(36, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _adjustSyncOffset(-1.0),
                        child: const Text('-1s'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(36, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _adjustSyncOffset(-0.5),
                        child: const Text('-0.5s'),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              syncOffsetSeconds != 0
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer
                                  : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${syncOffsetSeconds >= 0 ? '+' : ''}${syncOffsetSeconds.toStringAsFixed(1)}s',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                syncOffsetSeconds != 0
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                    : null,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(36, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _adjustSyncOffset(0.5),
                        child: const Text('+0.5s'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(36, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _adjustSyncOffset(1.0),
                        child: const Text('+1s'),
                      ),
                      if (syncOffsetSeconds != 0)
                        IconButton(
                          tooltip: 'Resetar sincronia',
                          icon: const Icon(Icons.restore, size: 20),
                          onPressed: () {
                            setState(() {
                              syncOffsetSeconds = 0.0;
                              if (sync) _updateSubtitle(position);
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ScrollablePositionedList.builder(
                itemCount: subtitles.length,
                itemScrollController: scrollCtrl,
                itemBuilder: (context, index) {
                  final s = subtitles[index];
                  final hl = (sync && index == currentIndex);
                  final text = _cueText(index);
                  final ctx = _contextFor(index);
                  final cueKey = '${_selectedLanguage.code}:$index';
                  final ankiKey = '${s.start.inMilliseconds}:${s.text.trim()}';
                  final sendingAnki = _ankiInFlight.contains(ankiKey);
                  final live = _streamingTranslations[cueKey];
                  final cached = _translationService.getCachedTranslation(
                    _selectedLanguage.code,
                    text,
                    context: ctx,
                  );
                  final shown =
                      (live != null && live.isNotEmpty) ? live : cached;
                  final inFlight = _translationInFlight.contains(cueKey);
                  return Container(
                    padding: const EdgeInsets.all(8),
                    color: hl ? ColorScheme.of(context).primaryContainer : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}',
                                style: TextStyle(fontSize: hl ? 25 : 18),
                              ),
                              WordTappableText(
                                s.text,
                                style: TextStyle(
                                  fontSize: hl ? 25 : 18,
                                  color: Colors.white,
                                ),
                                enabled: true,
                              ),
                              if (inFlight && (shown == null || shown.isEmpty))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Traduzindo para ${_selectedLanguage.name}…',
                                        style: TextStyle(
                                          fontSize: hl ? 16 : 14,
                                          color:
                                              ColorScheme.of(
                                                context,
                                              ).onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (shown != null && shown.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SelectableText(
                                    shown,
                                    style: TextStyle(
                                      fontSize: (hl ? 25 : 18) * 0.88,
                                      fontStyle: FontStyle.italic,
                                      height: 1.35,
                                      color:
                                          ColorScheme.of(
                                            context,
                                          ).onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final offset = Duration(
                              milliseconds: (syncOffsetSeconds * 1000).round(),
                            );
                            final target = s.start + offset;
                            player.seek(
                              target < Duration.zero ? Duration.zero : target,
                            );
                            player.resume();
                          },
                          icon: const Icon(Icons.play_circle_filled),
                        ),
                        IconButton(
                          tooltip:
                              'Traduzir para ${_selectedLanguage.name} (${_selectedLanguage.flag})',
                          onPressed: () => _translateCue(index),
                          icon: const Icon(Icons.translate),
                        ),
                        IconButton(
                          tooltip: 'Cortar áudio e enviar para o Anki',
                          onPressed:
                              sendingAnki
                                  ? null
                                  : () => _sendCueToAnki(s, index),
                          icon:
                              sendingAnki
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.content_cut),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}
