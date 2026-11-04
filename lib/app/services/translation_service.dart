import 'package:ollama_dart/ollama_dart.dart';

class TargetLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const TargetLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetLanguage &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class TranslationService {
  static final TranslationService instance = TranslationService._internal();
  TranslationService._internal();

  factory TranslationService() => instance;

  // ⚠️ Ajuste o nome do modelo conforme aparece no `ollama list`
  static const String modelName = 'maternion/hy-mt2:1.8b';

  final OllamaClient _client = OllamaClient();
  final Map<String, String> _cache = {};

  static const List<TargetLanguage> supportedLanguages = [
    TargetLanguage(
      code: 'pt',
      name: 'Português',
      nativeName: 'Português (Brasil)',
      flag: '🇧🇷',
    ),
    TargetLanguage(
      code: 'es',
      name: 'Espanhol',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
    TargetLanguage(
      code: 'en',
      name: 'Inglês',
      nativeName: 'English',
      flag: '🇺🇸',
    ),
    TargetLanguage(
      code: 'fr',
      name: 'Francês',
      nativeName: 'Français',
      flag: '🇫🇷',
    ),
  ];

  String _cacheKey(String targetCode, String text) => '$targetCode:$text';

  bool hasCachedTranslation(String targetCode, String text) {
    return _cache.containsKey(_cacheKey(targetCode, text));
  }

  String? getCachedTranslation(String targetCode, String text) {
    return _cache[_cacheKey(targetCode, text)];
  }

  /// Verifica se o modelo está disponível no Ollama
  Future<bool> isModelAvailable() async {
    try {
      final models = await _client.models.list();
      final available = models.models ?? [];
      return available.any(
        (m) =>
            m.name?.toLowerCase().contains(modelName.toLowerCase()) == true ||
            m.name == modelName,
      );
    } catch (e) {
      return false;
    }
  }

  /// Tradução normal (completa de uma vez)
  Future<String> translate({
    required String text,
    required TargetLanguage targetLanguage,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final key = _cacheKey(targetLanguage.code, trimmed);
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    try {
      final response = await _client.chat.create(
        request: ChatRequest(
          model: modelName,
          messages: [
            ChatMessage.system(_systemPrompt),
            ChatMessage.user(_buildUserPrompt(trimmed, targetLanguage)),
          ],
          options: const ModelOptions(temperature: 0.2),
        ),
      );

      final translated = response.message?.content?.trim() ?? '';

      if (translated.isNotEmpty) {
        _cache[key] = translated;
      }

      return translated;
    } catch (e) {
      throw Exception('Erro ao traduzir com Ollama ($modelName): $e');
    }
  }

  /// Tradução com streaming. Cada evento é o texto acumulado até aquele ponto.
  Stream<String> translateStream({
    required String text,
    required TargetLanguage targetLanguage,
  }) async* {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      yield '';
      return;
    }

    final key = _cacheKey(targetLanguage.code, trimmed);
    if (_cache.containsKey(key)) {
      yield _cache[key]!;
      return;
    }

    final buffer = StringBuffer();

    try {
      await for (final chunk in _client.chat.createStream(
        request: ChatRequest(
          model: modelName,
          messages: [
            ChatMessage.system(_systemPrompt),
            ChatMessage.user(_buildUserPrompt(trimmed, targetLanguage)),
          ],
          options: const ModelOptions(temperature: 0.2),
        ),
      )) {
        final content = chunk.message?.content ?? '';
        if (content.isEmpty) continue;
        buffer.write(content);
        yield buffer.toString();
      }

      final fullText = buffer.toString().trim();
      if (fullText.isNotEmpty) {
        _cache[key] = fullText;
      }
    } catch (e) {
      throw Exception('Erro no streaming de tradução ($modelName): $e');
    }
  }

  // Prompt de sistema otimizado para tradução de legendas
  static const String _systemPrompt = '''
Você é um tradutor profissional especializado em legendas de filmes e séries.
Traduza de forma natural, fluida e fiel ao original.
Mantenha o tom, gírias e estilo quando fizer sentido.
Responda APENAS com a tradução, sem explicações, aspas ou comentários.
''';

  String _buildUserPrompt(String text, TargetLanguage target) {
    return 'Traduza o seguinte texto para ${target.name} (${target.code}):\n\n$text';
  }

  void dispose() {
    _client.close();
  }
}
