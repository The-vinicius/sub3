import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sub3/app/models/sub.dart';
import 'package:sub3/app/services/youtube_download_service.dart';

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
                onPressed:
                    _loadingSubs || _downloading
                        ? null
                        : _loadSubtitleLanguages,
                icon:
                    _loadingSubs
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
                  decoration: const InputDecoration(labelText: 'Legenda'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SubtitleTrackOption>(
                      isExpanded: true,
                      value: _selected,
                      items: [
                        for (final t in _tracks)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged:
                          _downloading
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
