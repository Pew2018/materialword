import 'dart:convert';

import '../core/database/app_database.dart';

/// Export formats for one word book.
///
/// This is a *content* export (what is in the book), never a learning backup:
/// no review events, learning states or settings are included. The full backup
/// lives in 设置 → 备份与恢复.
enum WordBookExportFormat {
  txt('txt', '纯文本（每行一个单词）'),
  csv('csv', 'CSV（含释义与例句）'),
  json('json', 'JSON（结构化字段，可无损往返）');

  const WordBookExportFormat(this.extension, this.label);

  final String extension;
  final String label;
}

/// A book with its live words, as handed to the exporter.
class WordBookExport {
  const WordBookExport({required this.book, required this.words});

  final WordBook book;
  final List<Word> words;
}

/// Writes word-book content in the three exchange formats.
///
/// Format contract (see `docs/wordbook-exchange-format.md`):
///
/// | format | promise |
/// |---|---|
/// | TXT | one spelling per line. No meaning, no history. |
/// | CSV | structured content for spreadsheets. Formula prefixes are
///   neutralised with a leading apostrophe, so it is *safe*, not lossless. |
/// | JSON | the native exchange format: every content field this build stores
///   (`phonetic`, `partOfSpeech`, `translation`, `definition`, `example`,
///   `phrase`, `note`, `examTags`, `bncRank`, `frqRank`) plus book name and
///   description. No ids, no `source`/`revision` bookkeeping, no secrets. |
///
/// JSON has two accepted shapes: the versioned object written by
/// [encodeBook]/[encodeBooks], and the bare array written by earlier builds
/// ([encode] with [WordBookExportFormat.json]). Both are importable.
class WordBookExporter {
  const WordBookExporter._();

  static const int exchangeVersion = 2;
  static const String exchangeKind = 'materialword-wordbook';

  static const List<String> csvColumns = <String>[
    'word',
    'phonetic',
    'partOfSpeech',
    'translation',
    'definition',
    'example',
    'phrase',
    'note',
    'examTags',
  ];

  /// Legacy entry point kept for callers (and tests) that only have words.
  /// CSV and TXT are identical to the book-aware form; JSON is the historical
  /// bare array, which the importer still accepts.
  static String encode(List<Word> words, WordBookExportFormat format) {
    switch (format) {
      case WordBookExportFormat.txt:
        return _txt(words);
      case WordBookExportFormat.csv:
        return _csv(words, csvColumns);
      case WordBookExportFormat.json:
        return const JsonEncoder.withIndent('  ')
            .convert(<Map<String, Object?>>[
              for (final Word word in words) _wordJson(word),
            ]);
    }
  }

  /// One book, all formats. JSON is the versioned object with book metadata.
  static String encodeBook(
    WordBookExport export,
    WordBookExportFormat format, {
    DateTime? exportedAt,
  }) {
    switch (format) {
      case WordBookExportFormat.txt:
        return _txt(export.words);
      case WordBookExportFormat.csv:
        return _csv(export.words, csvColumns);
      case WordBookExportFormat.json:
        return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'kind': exchangeKind,
          'schemaVersion': exchangeVersion,
          if (exportedAt != null)
            'exportedAt': exportedAt.toUtc().toIso8601String(),
          'name': export.book.name,
          'description': export.book.description,
          'wordCount': export.words.length,
          'words': <Map<String, Object?>>[
            for (final Word word in export.words) _wordJson(word),
          ],
        });
    }
  }

  /// Several books at once. Book membership survives the round trip:
  /// re-importing creates one book per section and links the words to it,
  /// while a word that appears in two books stays a single row.
  static String encodeBooks(
    List<WordBookExport> exports,
    WordBookExportFormat format, {
    DateTime? exportedAt,
  }) {
    switch (format) {
      case WordBookExportFormat.txt:
        // A flat spelling list cannot carry membership; deduplicate instead of
        // repeating words the user would then have to clean up.
        final Set<String> seen = <String>{};
        return _txt(<Word>[
          for (final WordBookExport export in exports)
            for (final Word word in export.words)
              if (seen.add(word.normalized)) word,
        ]);
      case WordBookExportFormat.csv:
        return _csvMulti(exports);
      case WordBookExportFormat.json:
        return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'kind': exchangeKind,
          'schemaVersion': exchangeVersion,
          if (exportedAt != null)
            'exportedAt': exportedAt.toUtc().toIso8601String(),
          'books': <Map<String, Object?>>[
            for (final WordBookExport export in exports)
              <String, Object?>{
                'name': export.book.name,
                'description': export.book.description,
                'wordCount': export.words.length,
                'words': <Map<String, Object?>>[
                  for (final Word word in export.words) _wordJson(word),
                ],
              },
          ],
        });
    }
  }

  static String _txt(List<Word> words) {
    final StringBuffer buffer = StringBuffer();
    for (final Word word in words) {
      buffer.writeln(word.word);
    }
    return buffer.toString();
  }

  static String _csv(List<Word> words, List<String> columns) {
    final StringBuffer buffer = StringBuffer()..writeln(columns.join(','));
    for (final Word word in words) {
      buffer.writeln(
        columns
            .map((String column) => _csvField(_cell(word, column)))
            .join(','),
      );
    }
    return buffer.toString();
  }

  static String _csvMulti(List<WordBookExport> exports) {
    const List<String> columns = <String>['book', ...csvColumns];
    final StringBuffer buffer = StringBuffer()..writeln(columns.join(','));
    for (final WordBookExport export in exports) {
      for (final Word word in export.words) {
        buffer.writeln(
          columns
              .map(
                (String column) => _csvField(
                  column == 'book' ? export.book.name : _cell(word, column),
                ),
              )
              .join(','),
        );
      }
    }
    return buffer.toString();
  }

  static String _cell(Word word, String column) => switch (column) {
    'word' => word.word,
    'phonetic' => word.phonetic,
    'partOfSpeech' => word.partOfSpeech,
    'translation' => word.translation,
    'definition' => word.definition,
    'example' => word.example,
    'phrase' => word.phrase,
    'note' => word.note,
    'examTags' => word.examTags,
    _ => '',
  };

  /// RFC 4180 quoting: wrap in quotes when the field contains a separator,
  /// quote or line break, and double the inner quotes.
  ///
  /// Formula injection is handled separately: quoting alone does **not** stop a
  /// spreadsheet from evaluating `=HYPERLINK(...)` or `+cmd|...`, because the
  /// cell value is still a formula. Leading characters that Excel, LibreOffice
  /// and Numbers treat as a formula are therefore prefixed with an apostrophe,
  /// which forces a literal text cell. The stored word is untouched — this is
  /// an export-only transformation. CSV is therefore *safe*, not lossless; use
  /// JSON when byte-exact round-trips matter.
  static String _csvField(String value) {
    if (value.isEmpty) return '';
    final String guarded = sanitizeCsvCell(value);
    final bool needsQuotes =
        guarded.contains(',') ||
        guarded.contains('"') ||
        guarded.contains('\n') ||
        guarded.contains('\r');
    final String escaped = guarded.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  /// Characters that make a spreadsheet interpret a cell as a formula.
  static const String formulaPrefixes = '=+-@\t\r';

  /// Neutralises spreadsheet formula injection without touching the data.
  static String sanitizeCsvCell(String value) {
    if (value.isEmpty) return value;
    if (!formulaPrefixes.contains(value[0])) return value;
    return "'$value";
  }

  static Map<String, Object?> _wordJson(Word word) => <String, Object?>{
    'word': word.word,
    'phonetic': word.phonetic,
    'partOfSpeech': word.partOfSpeech,
    'translation': word.translation,
    'definition': word.definition,
    'example': word.example,
    'phrase': word.phrase,
    'note': word.note,
    'examTags': word.examTags,
    'bncRank': word.bncRank,
    'frqRank': word.frqRank,
  };
}
