import 'package:flirt_dict/core/text_utils.dart';
import 'package:flirt_dict/data/dictionary_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final dict = realDictionary;

  group('bundled dictionary data integrity', () {
    test('has a substantial number of entries and categories', () {
      expect(dict.length, greaterThanOrEqualTo(900));
      expect(dict.categories.length, 11);
    });

    test('every category has entries', () {
      for (final c in dict.categories) {
        expect(dict.inCategory(c.id), isNotEmpty, reason: c.id);
      }
    });

    test('ids are unique and non-empty', () {
      final ids = dict.entries.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids.every((id) => id.isNotEmpty), isTrue);
    });

    test('every entry has a definition and at least one example', () {
      for (final e in dict.entries) {
        expect(e.definition.length, greaterThan(10), reason: e.word);
        expect(e.examples, isNotEmpty, reason: e.word);
      }
    });

    test('every related word resolves to an entry', () {
      for (final e in dict.entries) {
        for (final r in e.related) {
          expect(dict.byWord(r), isNotNull, reason: '${e.word} -> $r');
          expect(dict.byWord(r)!.id, isNot(e.id), reason: 'self reference in ${e.word}');
        }
      }
    });

    test('entries are sorted alphabetically', () {
      final words = dict.entries.map((e) => foldText(e.word)).toList();
      expect(words, [...words]..sort());
    });

    test('letter grouping covers all entries', () {
      final total = dict.letterCounts().values.fold<int>(0, (a, b) => a + b);
      expect(total, dict.length);
      expect(dict.forLetter('G').every((e) => e.letter == 'G'), isTrue);
      for (final l in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
        expect(dict.forLetter(l), isNotEmpty, reason: 'no words for $l');
      }
    });

    test('letter of accented / multiword headwords', () {
      expect(dict.byWord('Tête-à-Tête')!.letter, 'T');
      expect(dict.byWord('A Catch')!.letter, 'A');
    });
  });

  group('word of the day', () {
    test('is stable within a day', () {
      final a = dict.wordOfTheDay(DateTime(2026, 11, 17, 0, 1));
      final b = dict.wordOfTheDay(DateTime(2026, 11, 17, 23, 59));
      expect(a.id, b.id);
    });

    test('changes between consecutive days', () {
      final a = dict.wordOfTheDay(DateTime(2026, 11, 17));
      final b = dict.wordOfTheDay(DateTime(2026, 11, 18));
      expect(a.id, isNot(b.id));
    });

    test('visits every entry once per cycle', () {
      final start = DateTime(2026);
      final seen = {
        for (var i = 0; i < dict.length; i++) dict.wordOfTheDay(start.add(Duration(days: i))).id,
      };
      expect(seen.length, dict.length);
    });

    test('works for dates before the epoch', () {
      expect(() => dict.wordOfTheDay(DateTime(1999, 1, 1)), returnsNormally);
    });
  });

  group('parsing robustness', () {
    test('skips malformed, duplicate and unknown-category entries', () {
      const raw = '''
      {"categories":[{"id":"a","label":"A"}, {"bad":true}],
       "entries":[
         {"word":"Good","pos":"noun","category":"a","definition":"Fine."},
         {"word":"Good","pos":"noun","category":"a","definition":"Duplicate."},
         {"word":"","pos":"noun","category":"a","definition":"No word."},
         {"word":"Orphan","pos":"noun","category":"zzz","definition":"Unknown cat."},
         {"word":"NoDef","pos":"noun","category":"a"},
         "not an object",
         {"word":"Bad list","pos":"noun","category":"a","definition":"x","examples":"nope"}
       ]}''';
      final d = DictionaryRepository.fromJsonString(raw);
      expect(d.entries.map((e) => e.word), ['Good']);
      expect(d.byWord('Good')!.definition, 'Fine.');
      expect(d.categories, hasLength(1));
    });

    test('rejects non-object roots', () {
      expect(() => DictionaryRepository.fromJsonString('[]'), throwsFormatException);
      expect(() => DictionaryRepository.fromJsonString('not json'), throwsFormatException);
    });

    test('empty dictionary throws on word of the day', () {
      final d = DictionaryRepository.fromJsonString('{"categories":[],"entries":[]}');
      expect(d.length, 0);
      expect(() => d.wordOfTheDay(DateTime(2026)), throwsStateError);
    });
  });

  test('share text includes word, definition and example', () {
    final e = dict.byWord('Ghosting')!;
    final text = e.toShareText();
    expect(text, contains('Ghosting (noun)'));
    expect(text, contains(e.definition));
    expect(text, contains(e.examples.first));
  });
}
