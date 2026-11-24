/// Dictionary text normalisation.
///
/// ECDICT (and many CSV/JSON exports built from it) store multi-line meanings
/// with *literal* backslash escapes: the two characters `\` + `n` instead of a
/// real newline. Older builds of the bundled dictionary shipped those escapes
/// straight to the UI, and rows written to the user database before the fix
/// still contain them. Everything that displays or stores dictionary text goes
/// through [normalizeDictionaryText] so the problem cannot come back through a
/// different import path.
///
/// Deliberately **not** applied to [kUserAuthoredFields]: personal notes may
/// legitimately contain a backslash sequence, and rewriting them would corrupt
/// the user's own words.
library;

/// Fields that come from a dictionary and may therefore be normalised.
const List<String> kDictionaryFields = <String>[
  'translation',
  'definition',
  'example',
  'phrase',
  'partOfSpeech',
];

/// Fields the user types themselves; never normalised behind their back.
const List<String> kUserAuthoredFields = <String>['note'];

/// True when [value] still contains a literal escape or a CR that the
/// normaliser would rewrite. Used to decide whether a stored row needs repair.
bool needsDictionaryNormalization(String value) {
  if (value.isEmpty) return false;
  if (value.contains('\r')) return true;
  return value.contains('\\n') ||
      value.contains('\\r') ||
      value.contains('\\t');
}

/// Turns literal `\n` / `\r\n` / `\t` escapes into real whitespace, unifies
/// line endings to `\n`, strips trailing spaces and collapses runs of blank
/// lines. Idempotent: normalising twice yields the same string.
String normalizeDictionaryText(String raw) {
  if (raw.isEmpty) return raw;

  String text = raw;

  // Literal escapes, longest first so `\r\n` is not half-handled.
  if (text.contains('\\')) {
    text = text
        .replaceAll('\\r\\n', '\n')
        .replaceAll('\\n', '\n')
        .replaceAll('\\r', '\n')
        .replaceAll('\\t', ' ');
  }

  // Real CRLF / CR.
  if (text.contains('\r')) {
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  // Per-line whitespace: trim trailing spaces/tabs but keep indentation-free
  // dictionary content readable.
  final List<String> lines = text.split('\n');
  for (int i = 0; i < lines.length; i++) {
    lines[i] = lines[i].replaceFirst(RegExp(r'[ \t]+$'), '');
  }

  // Collapse 2+ consecutive blank lines into a single blank line.
  final List<String> compact = <String>[];
  bool previousBlank = false;
  for (final String line in lines) {
    final bool blank = line.trim().isEmpty;
    if (blank && previousBlank) continue;
    compact.add(blank ? '' : line);
    previousBlank = blank;
  }

  return compact.join('\n').trim();
}

/// Normalises [raw], returning `null` when nothing is left.
String? normalizeDictionaryTextOrNull(String? raw) {
  if (raw == null) return null;
  final String normalized = normalizeDictionaryText(raw);
  return normalized.isEmpty ? null : normalized;
}

/// Compares two texts after normalisation — used by merge logic so that a
/// cosmetic escape-only difference is not treated as a content conflict.
bool sameDictionaryText(String a, String b) =>
    normalizeDictionaryText(a) == normalizeDictionaryText(b);
