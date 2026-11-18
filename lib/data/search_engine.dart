import '../core/text_utils.dart';
import 'models.dart';

/// Why an entry matched, from strongest to weakest.
enum MatchKind { exact, prefix, wordPrefix, contains, related, definition, other }

class SearchResult {
  const SearchResult(this.entry, this.kind);
  final WordEntry entry;
  final MatchKind kind;
}

class _Indexed {
  _Indexed(this.entry)
    : word = normalizeForSearch(entry.word),
      compactWord = normalizeForSearch(entry.word).replaceAll(' ', ''),
      related = normalizeForSearch(entry.related.join(' ')),
      definition = normalizeForSearch(entry.definition),
      rest = normalizeForSearch(
        '${entry.examples.join(' ')} ${entry.note ?? ''} ${entry.partOfSpeech}',
      );

  final WordEntry entry;
  final String word;
  final String compactWord;
  final String related;
  final String definition;
  final String rest;

  late final List<String> wordTokens = word.split(' ');
  // Pre-joined haystacks so queries don't allocate per entry.
  late final String wordRelated = '$word $related';
  late final String wordDefinition = '$word $definition';
  late final String everything = '$word $related $definition $rest';
  late final String sortKey = foldText(entry.word);
}

/// In-memory ranked search over the dictionary. The index is built once;
/// each query is a linear scan over pre-normalised strings, which is far
/// below a millisecond for a dictionary of this size.
class SearchEngine {
  SearchEngine(List<WordEntry> entries)
    : _index = entries.map(_Indexed.new).toList(growable: false);

  final List<_Indexed> _index;

  static const int maxQueryLength = 100;

  /// Queries shorter than this only match headword (word) prefixes.
  static const int minFullTextLength = 3;

  /// Returns ranked results. Empty or whitespace-only queries return an
  /// empty list. [categoryId] restricts results to one category.
  List<SearchResult> search(String query, {String? categoryId}) {
    final q = normalizeForSearch(_clip(query));
    if (q.isEmpty) return const [];
    final compactQ = q.replaceAll(' ', '');
    final tokens = q.split(' ');
    final matches = <(MatchKind, _Indexed)>[];
    for (final item in _index) {
      if (categoryId != null && item.entry.categoryId != categoryId) continue;
      final kind = _match(item, q, compactQ, tokens);
      if (kind != null) matches.add((kind, item));
    }
    matches.sort((a, b) {
      final byKind = a.$1.index.compareTo(b.$1.index);
      return byKind != 0 ? byKind : a.$2.sortKey.compareTo(b.$2.sortKey);
    });
    return [for (final m in matches) SearchResult(m.$2.entry, m.$1)];
  }

  MatchKind? _match(_Indexed i, String q, String compactQ, List<String> tokens) {
    if (i.word == q || i.compactWord == compactQ) return MatchKind.exact;
    if (i.word.startsWith(q) || i.compactWord.startsWith(compactQ)) {
      return MatchKind.prefix;
    }
    if (i.wordTokens.any((t) => t.startsWith(q))) return MatchKind.wordPrefix;
    // 1–2 character queries only match the start of headword words:
    // anything looser returns most of the dictionary (e.g. "h").
    if (q.length < minFullTextLength) return null;
    if (i.word.contains(q)) return MatchKind.contains;
    // Cheapest rejection first: every token must appear somewhere.
    if (!tokens.every(i.everything.contains)) return null;
    if (tokens.every(i.wordRelated.contains)) return MatchKind.related;
    if (tokens.every(i.wordDefinition.contains)) return MatchKind.definition;
    return MatchKind.other;
  }

  /// Headword autocomplete suggestions for [query].
  List<WordEntry> suggestions(String query, {int limit = 5}) {
    final q = normalizeForSearch(_clip(query));
    if (q.isEmpty) return const [];
    return search(q)
        .where((r) => r.kind.index <= MatchKind.wordPrefix.index)
        .take(limit)
        .map((r) => r.entry)
        .toList(growable: false);
  }

  /// Typo-tolerant "did you mean" suggestions, used when a search has no
  /// results. Only considers queries of at least 3 characters.
  List<WordEntry> didYouMean(String query, {int limit = 3}) {
    final q = normalizeForSearch(_clip(query)).replaceAll(' ', '');
    if (q.length < 3) return const [];
    final maxDistance = q.length <= 5 ? 1 : 2;
    final scored = <(int, _Indexed)>[];
    for (final item in _index) {
      // Compare against the whole word and against a same-length prefix, so
      // "ghostng" finds "ghosting" and "situationsip" finds "situationship".
      final whole = boundedLevenshtein(q, item.compactWord, maxDistance);
      final prefixLen = q.length.clamp(0, item.compactWord.length);
      final prefix = boundedLevenshtein(q, item.compactWord.substring(0, prefixLen), maxDistance);
      final d = whole < prefix ? whole : prefix;
      if (d <= maxDistance) scored.add((d, item));
    }
    scored.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : a.$2.word.compareTo(b.$2.word);
    });
    return scored.take(limit).map((s) => s.$2.entry).toList(growable: false);
  }

  static String _clip(String s) => s.length > maxQueryLength ? s.substring(0, maxQueryLength) : s;
}
