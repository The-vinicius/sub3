import 'package:flutter_test/flutter_test.dart';
import 'package:sub3/app/services/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TranslationService tests', () {
    test('TranslationService has supported languages list', () {
      expect(TranslationService.supportedLanguages.isNotEmpty, isTrue);
      final pt = TranslationService.supportedLanguages.firstWhere(
        (l) => l.code == 'pt',
      );
      expect(pt.name, 'Português');
      expect(pt.flag, '🇧🇷');

      final es = TranslationService.supportedLanguages.firstWhere(
        (l) => l.code == 'es',
      );
      expect(es.name, 'Espanhol');

      final en = TranslationService.supportedLanguages.firstWhere(
        (l) => l.code == 'en',
      );
      expect(en.name, 'Inglês');
    });

    test('TranslationService handles empty text without calling API', () async {
      final service = TranslationService.instance;
      final pt = TranslationService.supportedLanguages.first;
      final result = await service.translate(text: '   ', targetLanguage: pt);
      expect(result, isEmpty);
    });

    test('TargetLanguage equality works by code', () {
      const lang1 = TargetLanguage(
        code: 'fr',
        name: 'Francês',
        nativeName: 'Français',
        flag: '🇫🇷',
      );
      const lang2 = TargetLanguage(
        code: 'fr',
        name: 'French',
        nativeName: 'Français',
        flag: '🇫🇷',
      );
      expect(lang1, equals(lang2));
    });
  });
}
