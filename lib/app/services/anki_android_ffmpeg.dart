import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

Future<void> cutAudioWithEmbeddedFfmpeg({
  required String inputPath,
  required String outputPath,
  required String start,
  required String end,
}) async {
  final session = await FFmpegKit.executeWithArguments([
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-ss',
    start,
    '-to',
    end,
    '-i',
    inputPath,
    '-vn',
    '-c:a',
    'libmp3lame',
    '-q:a',
    '4',
    outputPath,
  ]);
  final code = await session.getReturnCode();
  if (!ReturnCode.isSuccess(code) || !File(outputPath).existsSync()) {
    final output = (await session.getOutput())?.trim() ?? '';
    throw StateError(
      output.isNotEmpty ? output : 'ffmpeg falhou ao cortar o áudio no Android.',
    );
  }
}
