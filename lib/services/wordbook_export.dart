import 'dart:convert';

import '../core/database/app_database.dart';

/// Export formats for one word book.
///
/// This is a *content* export (what is in the book), never a learning backup:
/// no review events, learning states, notes history or settings are included.
/// The full backup lives in 设置 → 备份与恢复.
enum WordBookExportFormat {
  txt('txt', '纯文本（每行一个单词）'),
  csv('csv', 'CSV（含释义与例句）'),
  json('json', 'JSON（结构化字段）');

  const WordBookExportFormat(this.extension, this.label);

  final String extension;
  final String label;
}

class WordBookExporter {
  const WordBookExporter._();

  static const List<String> csvColumns = <String>[
    'word',
    'phonetic',
    'partOfSpeech',
    'translation',
    'definition',
    'example',
    'phrase',
    'note',
  ];

  static String encode(List<Word> words, WordBookExportFormat format) {
    switch (format) {
      case WordBookExportFormat.txt:
        return _txt(words);
      case WordBookExportFormat.csv:
        return _csv(words);
      case WordBookExportFormat.json:
        return _json(words);
    }
  }

  static String _txt(List<Word> words) {
    final StringBuffer buffer = StringBuffer();
    for (final Word word in words) {
      buffer.writeln(word.word);
    }
    return buffer.toString();
  }

  static String _csv(List<Word> words) {
    final StringBuffer buffer = StringBuffer()..writeln(csvColumns.join(','));
    for (final Word word in words) {
      buffer.writeln(
        <String>[
          word.word,
          word.phonetic,
          word.partOfSpeech,
          word.translation,
          word.definition,
          word.example,
          word.phrase,
          word.note,
        ].map(_csvField).join(','),
      );
    }
    return buffer.toString();
  }

  /// RFC 4180 quoting: wrap in quotes when the field contains a separator,
  /// quote or line break, and double the inner quotes.
  ///
  /// Formula injection is handled separately: quoting alone does **not** stop a
  /// spreadsheet from evaluating `=HYPERLINK(...)` or `+cmd|...`, because the
  /// cell value is still a formula. Leading characters that Excel, LibreOffice
  /// and Numbers treat as a formula are therefore prefixed with an apostrophe,
  /// which forces a literal text cell. The stored word is untouched — this is
  /// an export-only transformation.
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

  static String _json(List<Word> words) {
    return const JsonEncoder.withIndent('  ').convert(<Map<String, Object?>>[
      for (final Word word in words)
        <String, Object?>{
          'word': word.word,
          'phonetic': word.phonetic,
          'partOfSpeech': word.partOfSpeech,
          'translation': word.translation,
          'definition': word.definition,
          'example': word.example,
          'phrase': word.phrase,
          'note': word.note,
          'examTags': word.examTags,
        },
    ]);
  }
}
