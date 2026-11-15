import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_gguf/flutter_gguf.dart' as gguf;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum GgufRuntimeState {
  unsupported,
  missing,
  downloading,
  ready,
  loading,
  loaded,
  error,
}

/// Downloads AngelSlim Hy-MT2 1.25Bit GGUF and runs it offline with flutter_gguf.
class GgufModelService extends ChangeNotifier {
  GgufModelService._internal();
  static final GgufModelService instance = GgufModelService._internal();

  static const String repoId = 'unsloth/Hy-MT2-1.8B-GGUF';
  static const String fileName = 'Hy-MT2-1.8B-Q4_K_M.gguf';
  static const String displayName = 'Hy-MT2 1.8B Q4_K_M';
  static const String downloadUrl =
      'https://huggingface.co/unsloth/Hy-MT2-1.8B-GGUF/resolve/main/Hy-MT2-1.8B-Q4_K_M.gguf';

  static bool get isOnDeviceSupported => !kIsWeb && Platform.isAndroid;

  GgufRuntimeState _state =
      isOnDeviceSupported
          ? GgufRuntimeState.missing
          : GgufRuntimeState.unsupported;
  double _progress = 0;
  int _bytesReceived = 0;
  int? _bytesTotal;
  String? _error;
  String? _modelPath;
  gguf.LlamaModel? _model;
  Future<gguf.LlamaModel>? _loadFuture;
  http.Client? _downloadClient;
  bool _cancelDownload = false;

  GgufRuntimeState get state => _state;
  double get progress => _progress;
  int get bytesReceived => _bytesReceived;
  int? get bytesTotal => _bytesTotal;
  String? get error => _error;
  String? get modelPath => _modelPath;
  bool get isDownloaded =>
      _state == GgufRuntimeState.ready ||
      _state == GgufRuntimeState.loading ||
      _state == GgufRuntimeState.loaded;
  bool get isLoaded => _state == GgufRuntimeState.loaded && _model != null;
  bool get isBusy =>
      _state == GgufRuntimeState.downloading ||
      _state == GgufRuntimeState.loading;

  String get statusLabel {
    switch (_state) {
      case GgufRuntimeState.unsupported:
        return 'Offline no Android (GGUF)';
      case GgufRuntimeState.missing:
        return 'Modelo offline não baixado';
      case GgufRuntimeState.downloading:
        return 'Baixando $displayName…';
      case GgufRuntimeState.ready:
        return 'Modelo baixado — toque para carregar';
      case GgufRuntimeState.loading:
        return 'Carregando modelo na memória…';
      case GgufRuntimeState.loaded:
        return 'Tradução offline pronta';
      case GgufRuntimeState.error:
        return _error ?? 'Erro no modelo offline';
    }
  }

  Future<void> refresh() async {
    if (!isOnDeviceSupported) {
      _setState(GgufRuntimeState.unsupported);
      return;
    }
    if (_state == GgufRuntimeState.downloading ||
        _state == GgufRuntimeState.loading) {
      return;
    }
    if (_model != null) {
      _setState(GgufRuntimeState.loaded);
      return;
    }
    final path = await localModelPath();
    final file = File(path);
    if (await file.exists() && await file.length() > 50 * 1024 * 1024) {
      _modelPath = path;
      _setState(GgufRuntimeState.ready);
    } else {
      _modelPath = null;
      _setState(GgufRuntimeState.missing);
    }
  }

  Future<String> localModelPath() async {
    final dir = await getApplicationSupportDirectory();
    final models = Directory(p.join(dir.path, 'models'));
    if (!await models.exists()) {
      await models.create(recursive: true);
    }
    return p.join(models.path, fileName);
  }

  Future<void> download({bool force = false}) async {
    if (!isOnDeviceSupported) {
      throw UnsupportedError(
        'Inferência GGUF com flutter_gguf está disponível apenas no Android.',
      );
    }
    if (_state == GgufRuntimeState.downloading) return;

    final destPath = await localModelPath();
    final dest = File(destPath);
    if (!force &&
        await dest.exists() &&
        await dest.length() > 50 * 1024 * 1024) {
      _modelPath = destPath;
      _setState(GgufRuntimeState.ready);
      return;
    }

    _cancelDownload = false;
    _error = null;
    _progress = 0;
    _bytesReceived = 0;
    _bytesTotal = null;
    _setState(GgufRuntimeState.downloading);

    final part = File('$destPath.part');
    var start = 0;
    if (await part.exists()) {
      start = await part.length();
    }

    _downloadClient?.close();
    final client = http.Client();
    _downloadClient = client;

    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'sub3/1.1.3 (flutter_gguf; Android)';
      request.headers['Accept'] = 'application/octet-stream';
      if (start > 0) {
        request.headers['Range'] = 'bytes=$start-';
      }

      final response = await client.send(request);
      if (response.statusCode == 416) {
        if (await dest.exists()) {
          await part.delete();
          _modelPath = destPath;
          _progress = 1;
          _setState(GgufRuntimeState.ready);
          return;
        }
        throw HttpException(
          'Servidor recusou retomar o download (HTTP 416).',
          uri: request.url,
        );
      }
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(
          'Falha ao baixar o modelo (HTTP ${response.statusCode}).',
          uri: request.url,
        );
      }

      final resumed = response.statusCode == 206;
      final contentLength = response.contentLength;
      if (contentLength != null && contentLength > 0) {
        _bytesTotal = resumed ? start + contentLength : contentLength;
      }

      if (!resumed && start > 0 && await part.exists()) {
        await part.delete();
        start = 0;
        _bytesReceived = 0;
      } else {
        _bytesReceived = start;
      }

      final sink = part.openWrite(mode: FileMode.append);
      try {
        await for (final chunk in response.stream) {
          if (_cancelDownload) {
            await sink.close();
            throw const _DownloadCancelled();
          }
          sink.add(chunk);
          _bytesReceived += chunk.length;
          if (_bytesTotal != null && _bytesTotal! > 0) {
            _progress = (_bytesReceived / _bytesTotal!).clamp(0.0, 1.0);
          }
          notifyListeners();
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (await dest.exists()) {
        await dest.delete();
      }
      await part.rename(destPath);

      final size = await dest.length();
      if (size < 50 * 1024 * 1024) {
        await dest.delete();
        throw StateError(
          'Arquivo GGUF incompleto (${_formatBytes(size)}). Tente baixar de novo.',
        );
      }

      _modelPath = destPath;
      _progress = 1;
      _setState(GgufRuntimeState.ready);
    } on _DownloadCancelled {
      _error = 'Download cancelado.';
      _setState(GgufRuntimeState.error);
    } catch (e) {
      _error = e.toString();
      _setState(GgufRuntimeState.error);
      rethrow;
    } finally {
      client.close();
      if (identical(_downloadClient, client)) {
        _downloadClient = null;
      }
    }
  }

  void cancelDownload() {
    _cancelDownload = true;
    _downloadClient?.close();
    _downloadClient = null;
  }

  Future<gguf.LlamaModel> ensureLoaded() async {
    if (!isOnDeviceSupported) {
      throw UnsupportedError(
        'Inferência GGUF com flutter_gguf está disponível apenas no Android.',
      );
    }
    if (_model != null) return _model!;
    if (_loadFuture != null) return _loadFuture!;

    final path = _modelPath ?? await localModelPath();
    final file = File(path);
    if (!await file.exists()) {
      throw StateError(
        'Baixe o modelo $displayName (~462 MB) para traduzir offline.',
      );
    }

    _modelPath = path;
    _error = null;
    _setState(GgufRuntimeState.loading);

    final threads = min(max(Platform.numberOfProcessors, 2), 6);
    _loadFuture = gguf.LlamaModel.load(
      path,
      params: gguf.ModelParams(
        contextSize: 2048,
        threads: threads,
        gpuLayers: 0,
      ),
    );

    try {
      _model = await _loadFuture!;
      _setState(GgufRuntimeState.loaded);
      return _model!;
    } catch (e) {
      _error =
          'Não foi possível carregar o GGUF. O quant 1.25Bit (STQ) exige '
          'kernel llama.cpp recente. Detalhe: $e';
      _setState(GgufRuntimeState.error);
      rethrow;
    } finally {
      _loadFuture = null;
    }
  }

  Stream<String> generateTranslation({required String prompt}) async* {
    final model = await ensureLoaded();
    final formatted = await _formatHyPrompt(model, prompt);
    final buffer = StringBuffer();
    await for (final piece in model.generate(
      formatted,
      params: const gguf.SamplingParams(
        temperature: 0.2,
        topP: 0.6,
        topK: 20,
        penaltyRepeat: 1.05,
        maxTokens: 256,
        seed: 42,
      ),
    )) {
      buffer.write(piece);
      yield _stripSpecialTokens(buffer.toString());
    }
  }

  Future<String> _formatHyPrompt(
    gguf.LlamaModel model,
    String userPrompt,
  ) async {
    try {
      final templated = await model.applyChatTemplate([
        gguf.ChatMessage.user(userPrompt),
      ], addAssistant: true);
      if (templated.trim().isNotEmpty &&
          !templated.contains('<|im_start|>') &&
          !templated.contains('im_start')) {
        return templated;
      }
    } catch (_) {
      // Use Hy-MT2 control tokens when the GGUF template is missing.
    }
    return '<｜hy_begin▁of▁sentence｜><｜hy_User｜>$userPrompt<｜hy_Assistant｜>';
  }

  String _stripSpecialTokens(String text) {
    return text
        .replaceAll(RegExp(r'<｜[^｜]*｜>'), '')
        .replaceAll(RegExp(r'<\|[^|]*\|>'), '')
        .trimLeft();
  }

  Future<void> unload() async {
    final model = _model;
    _model = null;
    if (model != null) {
      await model.dispose();
    }
    if (isOnDeviceSupported) {
      await refresh();
    }
  }

  void _setState(GgufRuntimeState next) {
    _state = next;
    notifyListeners();
  }

  static String formatBytes(int bytes) => _formatBytes(bytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}
