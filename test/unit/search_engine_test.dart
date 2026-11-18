import 'package:flirt_dict/data/search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final engine = SearchEngine(realDictionary.entries);
  List<String> words(String q, {String? cat}) =>
      engine.search(q, categoryId: cat).map((r) => r.entry.word).toList();

  group('search', () {
    test('empty / whitespace / punctuation-only queries return nothing', () {
      expect(engine.search(''), isEmpty);
      expect(engine.search('    '), isEmpty);
      expect(engine.search('!!!'), isEmpty);
    });

    test('exact match ranks first', () {
      expect(words('crush').first, 'Crush');
      expect(engine.search('crush').first.kind, MatchKind.exact);
    });

    test('is case- and diacritic-insensitive', () {
      expect(words('GHOSTING').first, 'Ghosting');
      expect(words('tete a tete').first, 'Tête-à-Tête');
      expect(words('cafune').first, 'Cafuné');
      expect(words('mon coeur').first, 'Mon Cœur');
      expect(words('coup de foudre').first, 'Coup de Foudre');
    });

    test('prefix matches rank above definition matches', () {
      final r = engine.search('ghost');
      expect(r.first.entry.word, 'Ghosting');
      expect(r.first.kind, MatchKind.prefix);
      // "Zombieing" mentions ghosting only in its definition / related.
      final kinds = {for (final x in r) x.entry.word: x.kind};
      expect(kinds['Zombieing']!.index, greaterThan(MatchKind.prefix.index));
    });

    test('matches inner word tokens of multi-word headwords', () {
      expect(words('flag'), containsAll(['Red Flag', 'Green Flag', 'Beige Flag']));
      expect(engine.search('flag').first.kind, MatchKind.wordPrefix);
    });

    test('ignores spacing and hyphens in headwords', () {
      expect(words('sweettalk').first, 'Sweet-Talk');
      expect(words('friendzone').first, 'Friend Zone');
    });

    test('multi-token queries require all tokens', () {
      final r = words('secret relationship');
      expect(r, isNotEmpty);
      for (final w in r) {
        final e = realDictionary.byWord(w)!;
        final hay =
            '${e.word} ${e.definition} ${e.related.join(' ')} ${e.examples.join(' ')} ${e.note ?? ''}'
                .toLowerCase();
        expect(hay.contains('secret'), isTrue, reason: w);
        expect(hay.contains('relationship'), isTrue, reason: w);
      }
    });

    test('category filter restricts results', () {
      final all = words('love');
      final classic = words('love', cat: 'classic');
      expect(classic.length, lessThan(all.length));
      for (final w in classic) {
        expect(realDictionary.byWord(w)!.categoryId, 'classic');
      }
    });

    test('unknown category returns nothing', () {
      expect(engine.search('love', categoryId: 'nope'), isEmpty);
    });

    test('1–2 letter queries only match headwords, not definitions', () {
      final h = words('h');
      expect(h, isNotEmpty);
      // Before the fix, 'h' matched ~99% of entries via definitions.
      expect(h.length, lessThan(realDictionary.length * 0.15));
      for (final w in h) {
        final starts = w.toLowerCase().split(RegExp(r'[\s-]+')).any((t) => t.startsWith('h'));
        expect(starts, isTrue, reason: w);
      }
      expect(words('h').first.toLowerCase(), startsWith('h'));
      // 3+ characters still search definitions too.
      expect(words('photos'), contains('Hard Launch')); // found via its definition
    });

    test('no results for nonsense', () {
      expect(engine.search('qzxqzxqzx'), isEmpty);
    });

    test('very long input is clipped, not crashing', () {
      expect(() => engine.search('a' * 10000), returnsNormally);
    });

    test('regex/special characters are treated literally', () {
      expect(() => engine.search(r'.*(\[+?'), returnsNormally);
      expect(engine.search(r'.*(\[+?'), isEmpty);
    });

    test('results are deterministic and alphabetical within a rank', () {
      final r = engine.search('love');
      for (var i = 1; i < r.length; i++) {
        if (r[i].kind == r[i - 1].kind) {
          expect(
            r[i - 1].entry.id.compareTo(r[i].entry.id) <= 0 ||
                r[i - 1].entry.word.toLowerCase().compareTo(r[i].entry.word.toLowerCase()) <= 0,
            isTrue,
          );
        }
      }
    });
  });

  group('suggestions', () {
    test('returns headword prefix matches only', () {
      final s = engine.suggestions('lov').map((e) => e.word);
      expect(s, isNotEmpty);
      expect(s.every((w) => w.toLowerCase().contains('lov')), isTrue);
      expect(s.length, lessThanOrEqualTo(5));
    });
    test('empty for empty query', () => expect(engine.suggestions(' '), isEmpty));
  });

  group('didYouMean', () {
    test('corrects common typos', () {
      expect(engine.didYouMean('ghostng').map((e) => e.word), contains('Ghosting'));
      expect(engine.didYouMean('situationsip').map((e) => e.word), contains('Situationship'));
      expect(engine.didYouMean('chrush').map((e) => e.word), contains('Crush'));
    });
    test('ignores very short queries', () {
      expect(engine.didYouMean('gh'), isEmpty);
    });
    test('returns nothing for distant strings', () {
      expect(engine.didYouMean('zzzzzzzzzz'), isEmpty);
    });
  });

  test('performance: 1,000 searches complete quickly', () {
    final sw = Stopwatch()..start();
    const queries = ['g', 'gh', 'gho', 'love', 'red flag', 'secret relationship', 'xyz'];
    for (var i = 0; i < 1000; i++) {
      engine.search(queries[i % queries.length]);
    }
    sw.stop();
    // Budget: 3ms per query in debug JIT on a slow PC (a frame is 16ms);
    // release AOT builds on phones are several times faster.
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });
}
