import 'package:flirt_dict/core/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('foldText', () {
    test('lower-cases and strips diacritics', () {
      expect(foldText('Tête-à-Tête'), 'tete-a-tete');
      expect(foldText('Cafuné'), 'cafune');
    });
    test('keeps length for supported characters', () {
      const s = 'Tête-à-Tête Cafuné';
      expect(foldText(s).length, s.length);
    });
  });

  group('normalizeForSearch', () {
    test('collapses punctuation and whitespace', () {
      expect(normalizeForSearch('  On-Again,   Off-Again!  '), 'on again off again');
    });
    test('empty and symbol-only input becomes empty', () {
      expect(normalizeForSearch(''), '');
      expect(normalizeForSearch('   '), '');
      expect(normalizeForSearch('?!.,'), '');
    });
  });

  group('slugify', () {
    test('produces stable url-safe ids', () {
      expect(slugify('Love at First Sight'), 'love-at-first-sight');
      expect(slugify('Tête-à-Tête'), 'tete-a-tete');
      expect(slugify("Steal Someone's Heart"), 'steal-someone-s-heart');
      expect(slugify('--Edge--'), 'edge');
    });
  });

  group('boundedLevenshtein', () {
    test('computes small distances', () {
      expect(boundedLevenshtein('ghost', 'ghost', 2), 0);
      expect(boundedLevenshtein('ghost', 'ghist', 2), 1);
      expect(boundedLevenshtein('kitten', 'sitting', 3), 3);
    });
    test('bails out beyond the bound', () {
      expect(boundedLevenshtein('a', 'abcdef', 2), 3);
      expect(boundedLevenshtein('abcdef', 'uvwxyz', 2), 3);
    });
  });
}
