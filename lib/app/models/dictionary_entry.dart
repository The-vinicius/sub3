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
    return DictionaryEntry(
      word: json['word'] ?? '',
      phonetic: json['phonetic'],
      phonetics: (json['phonetics'] as List<dynamic>?)
              ?.map((p) => Phonetic.fromJson(p))
              .toList() ??
          [],
      origin: json['origin'],
      meanings: (json['meanings'] as List<dynamic>?)
              ?.map((m) => Meaning.fromJson(m))
              .toList() ??
          [],
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
      text: json['text'],
      audio: json['audio'],
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
    return Meaning(
      partOfSpeech: json['partOfSpeech'] ?? '',
      definitions: (json['definitions'] as List<dynamic>?)
              ?.map((d) => Definition.fromJson(d))
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
    return Definition(
      definition: json['definition'] ?? '',
      example: json['example'],
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
