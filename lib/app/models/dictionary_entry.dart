class DictionaryEntry {
  final String word;
  final String? phonetic;
  final List<Phonetic> phonetics;
  final String? origin;
  final List<Meaning> meanings;

  DictionaryEntry({
    required this.word,
    this.phonetic,
    required this.phonetics,
    this.origin,
    required this.meanings,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    // Extract phonetics from 'phonetics' or from entries' 'pronunciations'
    final List<Phonetic> phonetics = [];
    if (json['phonetics'] is List) {
      phonetics.addAll(
        (json['phonetics'] as List<dynamic>)
            .map((p) => Phonetic.fromJson(p as Map<String, dynamic>)),
      );
    } else if (json['entries'] is List) {
      for (final entry in json['entries']) {
        if (entry is Map<String, dynamic> && entry['pronunciations'] is List) {
          for (final pron in entry['pronunciations']) {
            if (pron is Map<String, dynamic>) {
              phonetics.add(Phonetic.fromJson(pron));
            }
          }
        }
      }
    }

    String? phonetic = json['phonetic'] as String?;
    if (phonetic == null && phonetics.isNotEmpty) {
      phonetic = phonetics.first.text;
    }

    // Meanings from 'meanings' (legacy API) or 'entries' (freedictionaryapi)
    final rawMeanings = json['meanings'] ?? json['entries'];
    final meanings = (rawMeanings as List<dynamic>?)
            ?.map((m) => Meaning.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];

    return DictionaryEntry(
      word: json['word'] ?? '',
      phonetic: phonetic,
      phonetics: phonetics,
      origin: json['origin'] as String?,
      meanings: meanings,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'phonetic': phonetic,
        'phonetics': phonetics.map((p) => p.toJson()).toList(),
        'origin': origin,
        'meanings': meanings.map((m) => m.toJson()).toList(),
      };
}

class Phonetic {
  final String? text;
  final String? audio;

  Phonetic({this.text, this.audio});

  factory Phonetic.fromJson(Map<String, dynamic> json) {
    return Phonetic(
      text: json['text'] as String?,
      audio: json['audio'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'audio': audio,
      };
}

class Meaning {
  final String partOfSpeech;
  final List<Definition> definitions;
  final List<String> synonyms;
  final List<String> antonyms;

  Meaning({
    required this.partOfSpeech,
    required this.definitions,
    required this.synonyms,
    required this.antonyms,
  });

  factory Meaning.fromJson(Map<String, dynamic> json) {
    // Check if definitions come from 'definitions' (legacy) or 'senses' (freedictionaryapi)
    final defsList = json['definitions'] ?? json['senses'];
    return Meaning(
      partOfSpeech: json['partOfSpeech'] ?? '',
      definitions: (defsList as List<dynamic>?)
              ?.map((d) => Definition.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      synonyms: List<String>.from(json['synonyms'] as List<dynamic>? ?? []),
      antonyms: List<String>.from(json['antonyms'] as List<dynamic>? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'partOfSpeech': partOfSpeech,
        'definitions': definitions.map((d) => d.toJson()).toList(),
        'synonyms': synonyms,
        'antonyms': antonyms,
      };
}

class Definition {
  final String definition;
  final String? example;
  final List<String> synonyms;
  final List<String> antonyms;

  Definition({
    required this.definition,
    this.example,
    required this.synonyms,
    required this.antonyms,
  });

  factory Definition.fromJson(Map<String, dynamic> json) {
    String? example = json['example'] as String?;
    if (example == null &&
        json['examples'] is List &&
        (json['examples'] as List).isNotEmpty) {
      example = (json['examples'] as List).first?.toString();
    }

    return Definition(
      definition: json['definition'] ?? '',
      example: example,
      synonyms: List<String>.from(json['synonyms'] as List<dynamic>? ?? []),
      antonyms: List<String>.from(json['antonyms'] as List<dynamic>? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'definition': definition,
        'example': example,
        'synonyms': synonyms,
        'antonyms': antonyms,
      };
}
