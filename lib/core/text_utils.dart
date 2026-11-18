/// Text helpers shared by the data layer and search.
library;

const Map<String, String> _diacritics = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
  '’': "'", '‘': "'",
};

final RegExp _nonAlnum = RegExp(r'[^a-z0-9]+');
final RegExp _whitespace = RegExp(r'\s+');

/// Lower-cases [input] and strips common Latin diacritics, so that
/// "Tête-à-Tête" and "tete-a-tete" compare equal.
String foldText(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_diacritics[ch] ?? ch);
  }
  return buffer.toString();
}

/// Normalises free text for matching: folded, punctuation collapsed to
/// single spaces, trimmed.
String normalizeForSearch(String input) =>
    foldText(input).replaceAll(_nonAlnum, ' ').replaceAll(_whitespace, ' ').trim();

/// Stable URL-safe identifier derived from a headword.
String slugify(String input) =>
    foldText(input).replaceAll(_nonAlnum, '-').replaceAll(RegExp(r'^-+|-+$'), '');

/// Levenshtein edit distance, bailing out early once [maxDistance] is
/// exceeded (returns `maxDistance + 1` in that case).
int boundedLevenshtein(String a, String b, int maxDistance) {
  if ((a.length - b.length).abs() > maxDistance) return maxDistance + 1;
  if (a == b) return 0;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    var rowMin = current[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final v = [
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      current[j] = v;
      if (v < rowMin) rowMin = v;
    }
    if (rowMin > maxDistance) return maxDistance + 1;
    final tmp = previous;
    previous = current;
    current = tmp;
  }
  return previous[b.length];
}
