import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:sub3/app/models/sub.dart';
import 'package:sub3/app/ui/widgets/card_sub.dart';
import 'package:sub3/app/ui/widgets/word_tappable_text.dart';
import 'package:sub3/app/services/database_service.dart';
import 'package:sub3/app/services/youtube_download_service.dart';
import 'package:translator/translator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Subtitle Audio Player',
      theme: ThemeData.dark(),
      home: const FileSelectorScreen(),
    );
  }
}

class FileSelectorScreen extends StatefulWidget {
  const FileSelectorScreen({super.key});
  @override
  State<FileSelectorScreen> createState() => _FileSelectorScreenState();
}

class _FileSelectorScreenState extends State<FileSelectorScreen> {
  File? subtitleFile;
  File? audioFile;
  List<Sub> subs = [];
  final DatabaseService _databaseService = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _loadSubsFromDatabase();
  }

  // Load subs from database
  Future<void> _loadSubsFromDatabase() async {
    try {
      final loadedSubs = await _databaseService.getAllSubs();
      setState(() {
        subs = loadedSubs;
      });
    } catch (e) {}
  }

  // Save sub to database
  Future<bool> _saveSubToDatabase(Sub sub) async {
    try {
      await _databaseService.saveSub(sub);
      await _loadSubsFromDatabase(); // Reload the list
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subtitle "${sub.name}" saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving subtitle: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // Delete sub from database
  Future<void> _deleteSubFromDatabase(int id) async {
    try {
      await _databaseService.deleteSub(id);
      await _loadSubsFromDatabase(); // Reload the list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subtitle deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting subtitle: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> getPath(String name) async {
    final appDoc = await getApplicationDocumentsDirectory();
    final dest = File('${appDoc.path}/$name');
    return dest.path;
  }

  Future<void> pickSubtitle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      final path = await getPath(result.files.single.name);
      final ext = path.split('.').last.toLowerCase();
      if (['srt', 'vtt'].contains(ext)) {
        await File(result.files.single.path!).copy(path);
        setState(() => subtitleFile = File(path));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a .srt or .vtt file')),
        );
      }
    }
  }

  Future<void> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      final path = await getPath(result.files.single.name);
      await File(result.files.single.path!).copy(path);
      setState(() => audioFile = File(path));
    }
  }

  void openPlayer(Sub sub) {
    if (sub.subPath1.existsSync() && sub.mp3Path.existsSync()) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => SubtitlePlayerScreen(
                subtitleFile: sub.subPath1,
                audioFile: sub.mp3Path,
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('One or both files no longer exist')),
      );
    }
  }

  void subModal() {
    String subtitleName = '';
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Subtitle Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Subtitle Name'),
                  onChanged: (value) {
                    subtitleName = value;
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: pickSubtitle,
                  child: Text(
                    subtitleFile == null
                        ? 'Pick Subtitle (.srt/.vtt)'
                        : 'Subtitle: ${subtitleFile!.path.split(Platform.pathSeparator).last}',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: pickAudio,
                  child: Text(
                    audioFile == null
                        ? 'Pick Audio'
                        : 'Audio: ${audioFile!.path.split(Platform.pathSeparator).last}',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (subtitleFile != null && audioFile != null) {
                    final newSub = Sub(subtitleName, subtitleFile!, audioFile!);
                    final ok = await _saveSubToDatabase(newSub);
                    if (context.mounted && ok) {
                      Navigator.of(context).pop();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please select both subtitle and audio files',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _openYoutubeImportDialog() {
    if (!YoutubeDownloadService.isImportSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Importação do YouTube está disponível em Android e desktop (Linux, macOS, Windows).',
          ),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => YoutubeImportDialog(onSave: _saveSubToDatabase),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Files'),
        actions: [
          if (YoutubeDownloadService.isImportSupported)
            IconButton(
              tooltip: 'Importar do YouTube',
              icon: const Icon(Icons.cloud_download_outlined),
              onPressed: _openYoutubeImportDialog,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: subs.length,
          itemBuilder: (context, index) {
            final sub = subs[index];
            return CardSub(
              sub: sub,
              onTap: openPlayer,
              onDelete: (subToDelete) {
                if (subToDelete.id != null) {
                  _deleteSubFromDatabase(subToDelete.id!);
                }
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: subModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Diálogo: URL, idioma da legenda, nome opcional; desktop inclui caminho do yt-dlp.
class YoutubeImportDialog extends StatefulWidget {
  const YoutubeImportDialog({super.key, required this.onSave});

  final Future<bool> Function(Sub sub) onSave;

  @override
  State<YoutubeImportDialog> createState() => _YoutubeImportDialogState();
}

class _YoutubeImportDialogState extends State<YoutubeImportDialog> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _ytdlpPath = TextEditingController();
  final YoutubeDownloadService _svc = YoutubeDownloadService();

  List<SubtitleTrackOption> _tracks = [];
  SubtitleTrackOption? _selected;
  bool _loadingSubs = false;
  bool _downloading = false;
  String? _error;

  bool get _desktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  @override
  void initState() {
    super.initState();
    YoutubeDownloadService.getYtDlpBinaryPath().then((path) {
      if (!mounted || path == null || path.isEmpty) return;
      setState(() => _ytdlpPath.text = path);
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    _ytdlpPath.dispose();
    super.dispose();
  }

  Future<void> _applyYtDlpPathPref() async {
    if (!_desktop) return;
    final v = _ytdlpPath.text.trim();
    await YoutubeDownloadService.setYtDlpBinaryPath(v.isEmpty ? null : v);
  }

  Future<void> _loadSubtitleLanguages() async {
    final raw = _url.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Indique o URL ou ID do vídeo.');
      return;
    }
    if (YoutubeDownloadService.tryParseVideoId(raw) == null) {
      setState(() => _error = 'URL do YouTube inválido.');
      return;
    }
    setState(() {
      _error = null;
      _loadingSubs = true;
      _tracks = [];
      _selected = null;
    });
    try {
      await _applyYtDlpPathPref();
      final title = await _svc.resolveTitle(raw);
      final tracks = await _svc.listSubtitleTracks(raw);
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _selected = tracks.isNotEmpty ? tracks.first : null;
        if (_name.text.trim().isEmpty) {
          _name.text = title;
        }
        if (tracks.isEmpty) {
          _error = 'Nenhuma legenda listada para este vídeo.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loadingSubs = false);
    }
  }

  Future<void> _downloadAndSave() async {
    final raw = _url.text.trim();
    if (raw.isEmpty || YoutubeDownloadService.tryParseVideoId(raw) == null) {
      setState(() => _error = 'URL do YouTube inválido.');
      return;
    }
    if (_selected == null) {
      setState(() => _error = 'Carregue os idiomas e escolha uma legenda.');
      return;
    }
    setState(() {
      _error = null;
      _downloading = true;
    });
    try {
      await _applyYtDlpPathPref();
      final result = await _svc.download(
        urlOrId: raw,
        subtitle: _selected!,
        displayNameOverride:
            _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
      final displayName =
          _name.text.trim().isEmpty ? result.displayTitle : _name.text.trim();
      final ok = await widget.onSave(
        Sub(displayName, result.subtitleFile, result.audioFile),
      );
      if (mounted && ok) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importar do YouTube'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _url,
                decoration: const InputDecoration(
                  labelText: 'URL ou ID do vídeo',
                  hintText: 'https://www.youtube.com/watch?v=…',
                ),
                enabled: !_downloading,
              ),
              if (_desktop) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _ytdlpPath,
                  decoration: const InputDecoration(
                    labelText: 'Caminho do yt-dlp (opcional)',
                    hintText: 'yt-dlp ou /usr/bin/yt-dlp',
                  ),
                  enabled: !_downloading,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nome na lista (opcional)',
                ),
                enabled: !_downloading,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadingSubs || _downloading ? null : _loadSubtitleLanguages,
                icon: _loadingSubs
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate_outlined),
                label: const Text('Carregar idiomas de legenda'),
              ),
              if (_tracks.isNotEmpty) ...[
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Legenda',
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SubtitleTrackOption>(
                      isExpanded: true,
                      value: _selected,
                      items: [
                        for (final t in _tracks)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged: _downloading
                          ? null
                          : (v) => setState(() => _selected = v),
                    ),
                  ),
                ),
              ],
              if (_downloading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                const Text('A descarregar…'),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'O uso pode violar os Termos de Serviço do YouTube; '
                'utilize apenas conteúdo que tenha permissão para guardar.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _downloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed:
              _downloading || _loadingSubs || _selected == null
                  ? null
                  : _downloadAndSave,
          child: const Text('Baixar e guardar'),
        ),
      ],
    );
  }
}

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
  final GoogleTranslator _translator = GoogleTranslator();
  late StreamSubscription<Duration> posSub;
  late StreamSubscription<PlayerState> stateSub;

  final List<Subtitle> subtitles = [];
  final ItemScrollController scrollCtrl = ItemScrollController();

  /// Texto original (EN) → tradução (PT); persiste na sessão desta tela.
  final Map<String, String> _ptTranslationCache = {};
  final Set<String> _translationInFlight = {};

  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  PlayerState playerState = PlayerState.completed;
  int currentIndex = 0;
  bool sync = true;

  @override
  void initState() {
    super.initState();
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

  void _updateSubtitle(Duration p) {
    for (int i = 0; i < subtitles.length; i++) {
      if (p >= subtitles[i].start && p <= subtitles[i].end) {
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

  void _togglePlay() {
    if (playerState == PlayerState.playing) {
      player.pause();
    } else {
      player.resume();
    }
  }

  Future<void> _translateCueToPt(String cueText) async {
    final key = cueText;
    if (key.trim().isEmpty) return;
    if (_ptTranslationCache.containsKey(key)) return;
    if (_translationInFlight.contains(key)) return;

    setState(() => _translationInFlight.add(key));
    try {
      final translation = await _translator.translate(
        cueText,
        from: 'en',
        to: 'pt',
      );
      if (!mounted) return;
      _ptTranslationCache[key] = translation.text;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro na tradução: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _translationInFlight.remove(key));
      } else {
        _translationInFlight.remove(key);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player')),
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
                                style: TextStyle(fontSize: hl ? 25 : 18, color: Colors.white),
                                enabled: true,
                              ),
                              if (_translationInFlight.contains(s.text))
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
                                        'Traduzindo…',
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
                              if (_ptTranslationCache.containsKey(s.text))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SelectableText(
                                    _ptTranslationCache[s.text]!,
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
                            player.seek(s.start);
                            player.resume();
                          },
                          icon: const Icon(Icons.play_circle_filled),
                        ),
                        IconButton(
                          tooltip: 'Traduzir (EN → PT)',
                          onPressed: () => _translateCueToPt(s.text),
                          icon: const Icon(Icons.translate),
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
