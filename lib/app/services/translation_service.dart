import 'package:dart_openai/dart_openai.dart';

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

class TranslationModel {
  final String id;
  final String name;
  final String description;

  const TranslationModel({
    required this.id,
    required this.name,
    required this.description,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class TranslationService {
  static final TranslationService instance = TranslationService._internal();
  TranslationService._internal();

  factory TranslationService() => instance;

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
    TargetLanguage(
      code: 'de',
      name: 'Alemão',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
    ),
    TargetLanguage(
      code: 'it',
      name: 'Italiano',
      nativeName: 'Italiano',
      flag: '🇮🇹',
    ),
    TargetLanguage(
      code: 'ja',
      name: 'Japonês',
      nativeName: '日本語',
      flag: '🇯🇵',
    ),
    TargetLanguage(
      code: 'ko',
      name: 'Coreano',
      nativeName: '한국어',
      flag: '🇰🇷',
    ),
    TargetLanguage(code: 'zh', name: 'Chinês', nativeName: '中文', flag: '🇨🇳'),
    TargetLanguage(
      code: 'ru',
      name: 'Russo',
      nativeName: 'Русский',
      flag: '🇷🇺',
    ),
  ];

  static const List<TranslationModel> supportedModels = [
    TranslationModel(
      id: 'gpt-4o-mini',
      name: 'GPT-4o Mini',
      description: 'Rápido, econômico e eficiente (Recomendado)',
    ),
    TranslationModel(
      id: 'gpt-5.6-luna',
      name: 'GPT-5.6 Luna',
      description: 'Mais rápida e precisa',
    ),
  ];

  // Cache: "languageCode:text" -> translatedText
  final Map<String, String> _cache = {};

  static String apiKey = const String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );
  static String? baseUrl;
  static String modelName = 'gpt-4o-mini';

  String get currentModel => modelName;

  void setModel(String model) {
    if (model.trim().isNotEmpty) {
      modelName = model.trim();
    }
  }

  void clearCache() {
    _cache.clear();
  }

  static const String _systemPrompt =
      'Você é um tradutor especialista em legendas de filmes e áudios. '
      'Traduza o texto fornecido com naturalidade, precisão e fluência para o idioma solicitado. '
      'Retorne APENAS o texto traduzido, sem explicações adicionais, sem aspas extras e sem notas.';

  void _configureOpenAI() {
    if (apiKey.isNotEmpty) {
      OpenAI.apiKey = apiKey;
    }
    if (baseUrl != null && baseUrl!.isNotEmpty) {
      OpenAI.baseUrl = baseUrl!;
    }
  }

  String _cacheKey(String targetCode, String text) => '$targetCode:$text';

  bool hasCachedTranslation(String targetCode, String text) {
    return _cache.containsKey(_cacheKey(targetCode, text));
  }

  String? getCachedTranslation(String targetCode, String text) {
    return _cache[_cacheKey(targetCode, text)];
  }

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

    _configureOpenAI();

    final userPrompt =
        'Traduza o seguinte texto para ${targetLanguage.name} (${targetLanguage.code}):\n"$trimmed"';

    final chatCompletion = await OpenAI.instance.chat.create(
      model: modelName,
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
              _systemPrompt,
            ),
          ],
        ),
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(userPrompt),
          ],
        ),
      ],
    );

    final contentItems = chatCompletion.choices.first.message.content;
    final translated =
        contentItems?.map((item) => item.text ?? '').join().trim() ?? '';

    if (translated.isNotEmpty) {
      _cache[key] = translated;
    }

    return translated;
  }
}
