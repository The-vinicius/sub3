import 'package:flutter_test/flutter_test.dart';
import 'package:sub3/app/models/dictionary_entry.dart';
import 'package:sub3/app/services/dictionary_service.dart';

void main() {
  group('DictionaryEntry - FreeDictionaryAPI parser', () {
    test('parses freedictionaryapi JSON response structure correctly', () {
      final json = {
        "word": "hello",
        "entries": [
          {
            "language": {"code": "en", "name": "English"},
            "partOfSpeech": "interjection",
            "pronunciations": [
              {
                "type": "ipa",
                "text": "/hɛˈloʊ/",
                "tags": ["General American"]
              }
            ],
            "forms": [
              {"word": "hallo", "tags": ["alternative"]}
            ],
            "senses": [
              {
                "definition": "A greeting (salutation) said when meeting someone.",
                "tags": [],
                "examples": ["Hello, everyone."],
                "synonyms": [],
                "antonyms": []
              }
            ],
            "synonyms": ["hi", "hey"],
            "antonyms": ["bye", "goodbye"]
          },
          {
            "language": {"code": "en", "name": "English"},
            "partOfSpeech": "noun",
            "pronunciations": [],
            "forms": [],
            "senses": [
              {
                "definition": "\"Hello!\" or an equivalent greeting.",
                "examples": ["They gave each other a quick hello."]
              }
            ],
            "synonyms": ["greeting"],
            "antonyms": []
          }
        ]
      };

      final entry = DictionaryEntry.fromJson(json);

      expect(entry.word, equals('hello'));
      expect(entry.phonetic, equals('/hɛˈloʊ/'));
      expect(entry.phonetics.length, equals(1));
      expect(entry.phonetics.first.text, equals('/hɛˈloʊ/'));
      expect(entry.meanings.length, equals(2));

      // First meaning
      final m1 = entry.meanings[0];
      expect(m1.partOfSpeech, equals('interjection'));
      expect(m1.synonyms, contains('hi'));
      expect(m1.antonyms, contains('bye'));
      expect(m1.definitions.length, equals(1));
      expect(m1.definitions.first.definition, contains('greeting (salutation)'));
      expect(m1.definitions.first.example, equals('Hello, everyone.'));

      // Second meaning
      final m2 = entry.meanings[1];
      expect(m2.partOfSpeech, equals('noun'));
      expect(m2.definitions.length, equals(1));
      expect(m2.definitions.first.example, equals('They gave each other a quick hello.'));
    });

    test('parses legacy dictionary API format if provided', () {
      final legacyJson = {
        "word": "test",
        "phonetic": "/tɛst/",
        "phonetics": [
          {"text": "/tɛst/", "audio": "https://api.dictionaryapi.dev/media/test.mp3"}
        ],
        "meanings": [
          {
            "partOfSpeech": "noun",
            "definitions": [
              {
                "definition": "A procedure intended to establish the quality, performance, or reliability of something.",
                "example": "a test of courage",
                "synonyms": [],
                "antonyms": []
              }
            ],
            "synonyms": ["trial", "experiment"],
            "antonyms": []
          }
        ]
      };

      final entry = DictionaryEntry.fromJson(legacyJson);

      expect(entry.word, equals('test'));
      expect(entry.phonetic, equals('/tɛst/'));
      expect(entry.phonetics.first.audio, equals('https://api.dictionaryapi.dev/media/test.mp3'));
      expect(entry.meanings.first.partOfSpeech, equals('noun'));
      expect(entry.meanings.first.definitions.first.example, equals('a test of courage'));
      expect(entry.meanings.first.synonyms, contains('trial'));
    });
  });

  group('DictionaryService integration & cache', () {
    test('fetches word definition from FreeDictionaryAPI', () async {
      final service = DictionaryService();
      final result = await service.fetchWordDefinition('hello');

      expect(result, isNotNull);
      expect(result!.word.toLowerCase(), equals('hello'));
      expect(result.meanings.isNotEmpty, isTrue);

      // Verify cached
      expect(service.getCacheSize(), equals(1));
      final cachedResult = await service.fetchWordDefinition('HELLO');
      expect(cachedResult, equals(result));
    });

    test('returns null for non-existent word', () async {
      final service = DictionaryService();
      final result = await service.fetchWordDefinition('nonexistentwordxyz123456');

      expect(result, isNull);
    });
  });
}
