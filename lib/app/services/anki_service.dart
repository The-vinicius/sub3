import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sub3/app/services/anki_android_ffmpeg.dart';

class AnkiService {
  AnkiService._();
  static final AnkiService instance = AnkiService._();

  static const String deckName = 'sub3';
  static const String modelName = 'sub3';
  static const String _ankiConnectUrl = 'http://127.0.0.1:8765';
  static const MethodChannel _androidChannel = MethodChannel('sub3/anki');

  /// Cuts [start]–[end] from [audioFile] and adds a note to Anki / AnkiDroid.
  /// Front: original subtitle + audio. Back: translation (if any).
  Future<void> sendCue({
    required File audioFile,
    required Duration start,
    required Duration end,
    required String sentence,
    String? translation,
  }) async {
    if (start < Duration.zero) start = Duration.zero;
    if (end <= start) {
      throw StateError('Intervalo de áudio inválido para este subtítulo.');
    }
    if (!audioFile.existsSync()) {
      throw StateError('Ficheiro de áudio não encontrado.');
    }

    final clip = await cutAudio(
      audioFile: audioFile,
      start: start,
      end: end,
      sentence: sentence,
    );
    try {
      final front = _htmlLines(sentence);
      final back = _htmlLines(translation);
      final translationField = back.isEmpty ? '(sem tradução)' : back;

      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _androidChannel.invokeMethod('addNote', {
            'sentence': front,
            'translation': translationField,
            'audioPath': clip.path,
          });
        } on PlatformException catch (e) {
          throw StateError(e.message ?? e.code);
        }
        return;
      }

      await _ensureDeck();
      await _ensureModel();
      final filename = p.basename(clip.path);
      final data = base64Encode(await clip.readAsBytes());

      await _invoke('addNote', {
        'note': {
          'deckName': deckName,
          'modelName': modelName,
          'fields': {
            'Sentence': front,
            'Audio': '',
            'Translation': translationField,
          },
          'options': {'allowDuplicate': true},
          'tags': ['sub3'],
          'audio': [
            {
              'filename': filename,
              'data': data,
              'fields': ['Audio'],
            },
          ],
        },
      });
    } finally {
      try {
        await clip.delete();
      } catch (_) {}
    }
  }

  Future<File> cutAudio({
    required File audioFile,
    required Duration start,
    required Duration end,
    required String sentence,
  }) async {
    final dir = await getTemporaryDirectory();
    final safeHash = sentence.hashCode.abs();
    final out = File(
      p.join(
        dir.path,
        'sub3_${start.inMilliseconds}_${end.inMilliseconds}_$safeHash.mp3',
      ),
    );
    if (out.existsSync()) {
      await out.delete();
    }

    if (!kIsWeb && Platform.isAndroid) {
      await cutAudioWithEmbeddedFfmpeg(
        inputPath: audioFile.path,
        outputPath: out.path,
        start: formatFfmpegTime(start),
        end: formatFfmpegTime(end),
      );
      return out;
    }

    final ProcessResult r;
    try {
      r = await Process.run('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-ss',
        formatFfmpegTime(start),
        '-to',
        formatFfmpegTime(end),
        '-i',
        audioFile.path,
        '-vn',
        '-c:a',
        'libmp3lame',
        '-q:a',
        '4',
        out.path,
      ]);
    } on ProcessException {
      throw StateError('ffmpeg não encontrado. Instale com: pacman -S ffmpeg');
    }

    if (r.exitCode != 0 || !out.existsSync()) {
      final err = (r.stderr as String).trim();
      throw StateError(
        err.isNotEmpty
            ? err
            : 'ffmpeg falhou ao cortar o áudio (código ${r.exitCode}).',
      );
    }
    return out;
  }

  static String formatFfmpegTime(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  Future<void> _ensureDeck() async {
    await _invoke('createDeck', {'deck': deckName});
  }

  Future<void> _ensureModel() async {
    final names = await _invoke('modelNames');
    final existing = <String>[];
    if (names is List) {
      for (final n in names) {
        existing.add(n.toString());
      }
    }
    if (existing.contains(modelName)) return;

    await _invoke('createModel', {
      'modelName': modelName,
      'inOrderFields': ['Sentence', 'Audio', 'Translation'],
      'css':
          '.card { font-family: arial; font-size: 22px; text-align: center; '
          'color: black; background-color: white; }',
      'isCloze': false,
      'cardTemplates': [
        {
          'Name': 'Card 1',
          'Front': '{{Audio}}<br>{{Sentence}}',
          'Back': '{{FrontSide}}<hr id=answer>{{Translation}}',
        },
      ],
    });
  }

  Future<dynamic> _invoke(String action, [Map<String, dynamic>? params]) async {
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_ankiConnectUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': action,
              'version': 6,
              if (params != null) 'params': params,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } on SocketException {
      throw StateError(
        'Anki não está a responder. Abra o Anki com o add-on AnkiConnect.',
      );
    } on http.ClientException {
      throw StateError(
        'Anki não está a responder. Abra o Anki com o add-on AnkiConnect.',
      );
    }

    if (res.statusCode != 200) {
      throw StateError('AnkiConnect HTTP ${res.statusCode}.');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Resposta inválida do AnkiConnect.');
    }
    final error = decoded['error'];
    if (error != null) {
      throw StateError(error.toString());
    }
    return decoded['result'];
  }

  String _htmlLines(String? text) {
    final t = (text ?? '').trim();
    if (t.isEmpty) return '';
    return const HtmlEscape().convert(t).replaceAll('\n', '<br>');
  }
}
