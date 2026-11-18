import '../core/text_utils.dart';

/// A dictionary category such as "Dating Slang".
class Category {
  const Category({required this.id, required this.label, required this.description});

  final String id;
  final String label;
  final String description;

  factory Category.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final label = json['label'];
    if (id is! String || id.isEmpty || label is! String || label.isEmpty) {
      throw FormatException('Invalid category: $json');
    }
    return Category(id: id, label: label, description: (json['description'] as String?) ?? '');
  }
}

/// A single dictionary headword with its definition and metadata.
class WordEntry {
  WordEntry({
    required this.word,
    required this.partOfSpeech,
    required this.categoryId,
    required this.definition,
    this.examples = const [],
    this.related = const [],
    this.note,
  }) : id = slugify(word),
       letter = _letterFor(word);

  /// Stable identifier (slug of [word]) used for persistence.
  final String id;
  final String word;
  final String partOfSpeech;
  final String categoryId;
  final String definition;
  final List<String> examples;

  /// Headwords of related entries.
  final List<String> related;
  final String? note;

  /// Upper-case A–Z initial used for alphabetical browsing, or `#`.
  final String letter;

  static String _letterFor(String word) {
    final folded = foldText(word);
    for (final unit in folded.codeUnits) {
      if (unit >= 0x61 && unit <= 0x7a) return String.fromCharCode(unit - 32);
    }
    return '#';
  }

  factory WordEntry.fromJson(Map<String, dynamic> json) {
    String requireString(String key) {
      final v = json[key];
      if (v is! String || v.trim().isEmpty) {
        throw FormatException('Entry missing "$key": $json');
      }
      return v.trim();
    }

    List<String> stringList(String key) {
      final v = json[key];
      if (v == null) return const [];
      if (v is! List) throw FormatException('"$key" must be a list: $json');
      return List.unmodifiable(
        v.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty),
      );
    }

    final note = json['note'];
    return WordEntry(
      word: requireString('word'),
      partOfSpeech: requireString('pos'),
      categoryId: requireString('category'),
      definition: requireString('definition'),
      examples: stringList('examples'),
      related: stringList('related'),
      note: note is String && note.trim().isNotEmpty ? note.trim() : null,
    );
  }

  /// Plain-text representation used for copy and share.
  String toShareText() {
    final b = StringBuffer()
      ..writeln('$word ($partOfSpeech)')
      ..writeln(definition);
    if (examples.isNotEmpty) {
      b
        ..writeln()
        ..writeln('“${examples.first}”');
    }
    b
      ..writeln()
      ..write('— from Flirt Dictionary');
    return b.toString();
  }
}

/// A user-created, named list of saved words.
class WordCollection {
  const WordCollection({
    required this.id,
    required this.name,
    required this.wordIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<String> wordIds;
  final DateTime createdAt;

  WordCollection copyWith({String? name, List<String>? wordIds}) => WordCollection(
    id: id,
    name: name ?? this.name,
    wordIds: wordIds ?? this.wordIds,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'wordIds': wordIds,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Returns `null` for malformed records instead of throwing, so one bad
  /// record never wipes the user's other collections.
  static WordCollection? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final ids = json['wordIds'];
    if (id is! String || name is! String || ids is! List) return null;
    return WordCollection(
      id: id,
      name: name,
      wordIds: ids.whereType<String>().toList(),
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    );
  }
}
