import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/text_utils.dart';
import 'models.dart';

/// Read-only, fully offline dictionary built from the bundled JSON asset.
class DictionaryRepository {
  DictionaryRepository._(this.categories, List<WordEntry> entries)
    : entries = List.unmodifiable(entries),
      _byId = {for (final e in entries) e.id: e},
      _categoryById = {for (final c in categories) c.id: c},
      _byCategory = {
        for (final c in categories)
          c.id: List.unmodifiable(entries.where((e) => e.categoryId == c.id)),
      },
      _byLetter = _groupByLetter(entries);

  static Map<String, List<WordEntry>> _groupByLetter(List<WordEntry> entries) {
    final map = <String, List<WordEntry>>{};
    for (final e in entries) {
      (map[e.letter] ??= []).add(e);
    }
    return map.map((k, v) => MapEntry(k, List.unmodifiable(v)));
  }

  static const String assetPath = 'assets/data/dictionary.json';

  final List<Category> categories;

  /// All entries sorted alphabetically (diacritic-insensitive).
  final List<WordEntry> entries;
  final Map<String, WordEntry> _byId;
  final Map<String, Category> _categoryById;
  final Map<String, List<WordEntry>> _byCategory;
  final Map<String, List<WordEntry>> _byLetter;

  static Future<DictionaryRepository> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    return DictionaryRepository.fromJsonString(raw);
  }

  /// Parses and validates the dictionary. Malformed entries, unknown
  /// categories and duplicates are skipped rather than crashing the app.
  factory DictionaryRepository.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Dictionary root must be an object');
    }
    final categories = <Category>[];
    for (final c in (decoded['categories'] as List? ?? const [])) {
      if (c is Map<String, dynamic>) {
        try {
          categories.add(Category.fromJson(c));
        } on FormatException {
          // Skip malformed category.
        }
      }
    }
    final known = categories.map((c) => c.id).toSet();
    final seen = <String>{};
    final entries = <WordEntry>[];
    for (final e in (decoded['entries'] as List? ?? const [])) {
      if (e is! Map<String, dynamic>) continue;
      try {
        final entry = WordEntry.fromJson(e);
        if (entry.id.isEmpty || !known.contains(entry.categoryId)) continue;
        if (!seen.add(entry.id)) continue;
        entries.add(entry);
      } on FormatException {
        // Skip malformed entry.
      }
    }
    entries.sort((a, b) => foldText(a.word).compareTo(foldText(b.word)));
    return DictionaryRepository._(List.unmodifiable(categories), entries);
  }

  int get length => entries.length;

  WordEntry? byId(String id) => _byId[id];

  /// Resolves a headword (as used in `related`) to its entry.
  WordEntry? byWord(String word) => _byId[slugify(word)];

  Category? categoryById(String id) => _categoryById[id];

  List<WordEntry> inCategory(String categoryId) => _byCategory[categoryId] ?? const [];

  List<WordEntry> forLetter(String letter) => _byLetter[letter] ?? const [];

  /// Number of entries per initial letter.
  Map<String, int> letterCounts() => _byLetter.map((k, v) => MapEntry(k, v.length));

  /// Deterministic "word of the day": stable for a calendar day, rotates
  /// through every entry before repeating.
  WordEntry wordOfTheDay(DateTime now) {
    if (entries.isEmpty) throw StateError('Dictionary is empty');
    final day = DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(2024)).inDays;
    // 7919 is prime and larger than the dictionary, so multiplying by it
    // permutes the indices and avoids alphabetical day-to-day order.
    final index = (day * 7919) % entries.length;
    return entries[index < 0 ? index + entries.length : index];
  }
}
