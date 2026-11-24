import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/database/app_database.dart';
import '../core/repositories/word_repository.dart';
import '../core/repositories/wordbook_repository.dart';
import 'dictionary_service.dart';

/// One parsed row coming from a TXT / CSV / JSON file.
class ParsedEntry {
  const ParsedEntry({
    required this.word,
    this.phonetic = '',
    this.partOfSpeech = '',
    this.translation = '',
    this.definition = '',
    this.example = '',
    this.note = '',
  });

  final String word;
  final String phonetic;
  final String partOfSpeech;
  final String translation;
  final String definition;
  final String example;
  final String note;

  String get key => normalizeWordKey(word);
}

class ImportIssue {
  const ImportIssue(this.line, this.reason);

  final String line;
  final String reason;
}

/// Everything the confirmation dialog needs before touching the database.
class ImportPreview {
  const ImportPreview({
    required this.entries,
    required this.format,
    required this.detectedBookName,
    this.duplicateCount = 0,
    this.invalidCount = 0,
    this.issues = const <ImportIssue>[],
    this.sourceUrl = '',
  });

  final List<ParsedEntry> entries;
  final String format;
  final String detectedBookName;
  final int duplicateCount;
  final int invalidCount;
  final List<ImportIssue> issues;
  final String sourceUrl;

  int get validCount => entries.length;

  bool get isEmpty => entries.isEmpty && invalidCount == 0;
}

class ImportOutcome {
  const ImportOutcome({
    required this.created,
    required this.existing,
    required this.linked,
    required this.duplicateInFile,
    required this.invalid,
  });

  final int created;
  final int existing;
  final int linked;
  final int duplicateInFile;
  final int invalid;

  String get summary =>
      '新增 $created 个词条，已存在 $existing 个，关联 $linked 个到词书'
      '${duplicateInFile > 0 ? '，文件内重复 $duplicateInFile 个' : ''}'
      '${invalid > 0 ? '，忽略无效 $invalid 行' : ''}';
}

/// File/URL import: parse first (never touching the DB), then commit in a
/// single transaction so a bad file cannot damage existing data.
class ImportService {
  ImportService({
    required this.words,
    required this.wordBooks,
    this.dictionary,
  });

  final WordRepository words;
  final WordBookRepository wordBooks;
  final DictionaryService? dictionary;

  static const int maxEntries = 20000;
  static const int maxFileBytes = 8 * 1024 * 1024;

  Future<ImportPreview> parseFile(String path, {String? fileName}) async {
    final File file = File(path);
    final int length = await file.length();
    if (length > maxFileBytes) {
      throw const FormatException('文件过大（上限 8 MB）');
    }
    final String content = const Utf8Decoder(allowMalformed: true)
        .convert(await file.readAsBytes());
    final String name = fileName ?? path.split(Platform.pathSeparator).last;
    final String format = _detectFormat(name, content);
    return parseContent(content, format: format, name: name);
  }

  Future<ImportPreview> fetchUrl(String url) async {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException('只支持 HTTPS 地址');
    }
    final http.Response response = await http
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw FormatException('下载失败：HTTP ${response.statusCode}');
    }
    final String content = const Utf8Decoder(allowMalformed: true)
        .convert(response.bodyBytes);
    if (content.length > maxFileBytes) {
      throw const FormatException('文件过大（上限 8 MB）');
    }
    final String format = _detectFormat(uri.path, content);
    final String name = uri.pathSegments.isEmpty
        ? '在线词表'
        : uri.pathSegments.last;
    final ImportPreview preview = parseContent(
      content,
      format: format,
      name: name,
    );
    return ImportPreview(
      entries: preview.entries,
      format: preview.format,
      detectedBookName: preview.detectedBookName,
      duplicateCount: preview.duplicateCount,
      invalidCount: preview.invalidCount,
      issues: preview.issues,
      sourceUrl: uri.toString(),
    );
  }

  String _detectFormat(String name, String content) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.json')) return 'json';
    if (lower.endsWith('.csv')) return 'csv';
    if (lower.endsWith('.txt')) return 'txt';
    final String trimmed = content.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) return 'json';
    if (trimmed.split('\n').first.toLowerCase().contains('word,')) return 'csv';
    return 'txt';
  }

  ImportPreview parseContent(
    String rawContent, {
    required String format,
    String name = 'import',
  }) {
    final String content = rawContent.replaceFirst('\uFEFF', '');
    switch (format) {
      case 'json':
        return _parseJson(content, name);
      case 'csv':
        return _parseCsv(content, name);
      case 'txt':
      default:
        return _parseTxt(content, name);
    }
  }

  ImportPreview _parseTxt(String content, String name) {
    final List<ParsedEntry> entries = <ParsedEntry>[];
    final Set<String> seen = <String>{};
    final List<ImportIssue> issues = <ImportIssue>[];
    int duplicate = 0;
    int invalid = 0;
    final List<String> lines = const LineSplitter().convert(content);

    for (final String rawLine in lines) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      // "apple" or "apple\t苹果；n. 苹果"
      final List<String> parts = line
          .split(RegExp(r'\t|,(?=[^\s])'))
          .map((String p) => p.trim())
          .toList();
      final String word = parts.first;
      if (!_looksLikeWord(word)) {
        invalid++;
        if (issues.length < 20) issues.add(ImportIssue(line, '不是合法英文单词'));
        continue;
      }
      final ParsedEntry entry = ParsedEntry(
        word: word,
        translation: parts.length > 1 ? parts.sublist(1).join(' ').trim() : '',
      );
      if (!seen.add(entry.key)) {
        duplicate++;
        continue;
      }
      entries.add(entry);
      if (entries.length >= maxEntries) break;
    }
    return ImportPreview(
      entries: entries,
      format: 'txt',
      detectedBookName: _bookNameFrom(name),
      duplicateCount: duplicate,
      invalidCount: invalid,
      issues: issues,
    );
  }

  ImportPreview _parseCsv(String content, String name) {
    final List<List<String>> rows = _parseCsvRows(content);
    if (rows.isEmpty) {
      return ImportPreview(
        entries: const <ParsedEntry>[],
        format: 'csv',
        detectedBookName: _bookNameFrom(name),
      );
    }
    final List<String> header = rows.first
        .map((String h) => h.trim().toLowerCase())
        .toList();
    int column(String key) => header.indexOf(key);
    final int wordIndex = column('word');
    if (wordIndex < 0) {
      throw const FormatException('CSV 缺少必需的 word 列');
    }
    final int phoneticIndex = column('phonetic');
    final int posIndex = header.contains('pos')
        ? header.indexOf('pos')
        : header.indexOf('part_of_speech');
    final int translationIndex = column('translation');
    final int definitionIndex = column('definition');
    final int exampleIndex = header.contains('example')
        ? header.indexOf('example')
        : header.indexOf('sentence');
    final int noteIndex = column('note');

    String cell(List<String> row, int index) =>
        index >= 0 && index < row.length ? row[index].trim() : '';

    final List<ParsedEntry> entries = <ParsedEntry>[];
    final Set<String> seen = <String>{};
    final List<ImportIssue> issues = <ImportIssue>[];
    int duplicate = 0;
    int invalid = 0;

    for (int i = 1; i < rows.length; i++) {
      final List<String> row = rows[i];
      if (row.every((String c) => c.trim().isEmpty)) continue;
      final String word = cell(row, wordIndex);
      if (!_looksLikeWord(word)) {
        invalid++;
        if (issues.length < 20) {
          issues.add(ImportIssue(row.join(','), '第 ${i + 1} 行 word 无效'));
        }
        continue;
      }
      final ParsedEntry entry = ParsedEntry(
        word: word,
        phonetic: cell(row, phoneticIndex),
        partOfSpeech: cell(row, posIndex),
        translation: cell(row, translationIndex),
        definition: cell(row, definitionIndex),
        example: cell(row, exampleIndex),
        note: cell(row, noteIndex),
      );
      if (!seen.add(entry.key)) {
        duplicate++;
        continue;
      }
      entries.add(entry);
      if (entries.length >= maxEntries) break;
    }
    return ImportPreview(
      entries: entries,
      format: 'csv',
      detectedBookName: _bookNameFrom(name),
      duplicateCount: duplicate,
      invalidCount: invalid,
      issues: issues,
    );
  }

  ImportPreview _parseJson(String content, String name) {
    final Object? decoded = jsonDecode(content);
    String bookName = _bookNameFrom(name);
    List<dynamic> rawWords = const <dynamic>[];
    if (decoded is Map<String, dynamic>) {
      final Object? version = decoded['schemaVersion'];
      if (version is int && version > 1) {
        throw const FormatException('词书文件版本过新');
      }
      final Object? wordsNode = decoded['words'] ?? decoded['entries'];
      if (wordsNode is! List<dynamic>) {
        throw const FormatException('JSON 缺少 words 数组');
      }
      rawWords = wordsNode;
      final Object? declaredName = decoded['name'] ?? decoded['bookName'];
      if (declaredName is String && declaredName.trim().isNotEmpty) {
        bookName = declaredName.trim();
      }
    } else if (decoded is List<dynamic>) {
      rawWords = decoded;
    } else {
      throw const FormatException('无法识别的 JSON 结构');
    }

    final List<ParsedEntry> entries = <ParsedEntry>[];
    final Set<String> seen = <String>{};
    final List<ImportIssue> issues = <ImportIssue>[];
    int duplicate = 0;
    int invalid = 0;

    for (final dynamic node in rawWords) {
      String word = '';
      String phonetic = '';
      String pos = '';
      String translation = '';
      String definition = '';
      String example = '';
      String note = '';
      if (node is String) {
        word = node;
      } else if (node is Map<String, dynamic>) {
        word = (node['word'] ?? node['name'] ?? '').toString();
        phonetic = (node['phonetic'] ?? '').toString();
        pos = (node['pos'] ?? node['partOfSpeech'] ?? '').toString();
        translation = (node['translation'] ?? node['meaning'] ?? '').toString();
        definition = (node['definition'] ?? '').toString();
        example = (node['example'] ?? node['sentence'] ?? '').toString();
        note = (node['note'] ?? '').toString();
      }
      if (!_looksLikeWord(word)) {
        invalid++;
        if (issues.length < 20) issues.add(ImportIssue(word, '无效词条'));
        continue;
      }
      final ParsedEntry entry = ParsedEntry(
        word: word.trim(),
        phonetic: phonetic,
        partOfSpeech: pos,
        translation: translation,
        definition: definition,
        example: example,
        note: note,
      );
      if (!seen.add(entry.key)) {
        duplicate++;
        continue;
      }
      entries.add(entry);
      if (entries.length >= maxEntries) break;
    }

    return ImportPreview(
      entries: entries,
      format: 'json',
      detectedBookName: bookName,
      duplicateCount: duplicate,
      invalidCount: invalid,
      issues: issues,
    );
  }

  /// Writes the preview into the database inside one transaction.
  Future<ImportOutcome> commit({
    required ImportPreview preview,
    required String bookId,
    required DateTime now,
    bool enrichFromDictionary = true,
  }) async {
    int created = 0;
    int existing = 0;
    int linked = 0;

    await words.db.transaction(() async {
      final int before = await wordBooks.wordCount(bookId);
      for (final ParsedEntry entry in preview.entries) {
        final Word? found = await words.byNormalized(
          entry.key,
          includeDeleted: true,
        );
        Word word;
        if (found == null) {
          DictionaryEntry? lookup;
          if (enrichFromDictionary && dictionary != null) {
            lookup = await dictionary!.lookup(entry.word);
          }
          word = await words.ensureWord(
            text: entry.word,
            phonetic: entry.phonetic.isNotEmpty
                ? entry.phonetic
                : (lookup?.phonetic ?? ''),
            partOfSpeech: entry.partOfSpeech.isNotEmpty
                ? entry.partOfSpeech
                : (lookup?.partOfSpeech ?? ''),
            translation: entry.translation.isNotEmpty
                ? entry.translation
                : (lookup?.translation ?? ''),
            definition: entry.definition.isNotEmpty
                ? entry.definition
                : (lookup?.definition ?? ''),
            example: entry.example,
            note: entry.note,
            source: 'import',
            examTags: lookup?.examTags ?? '',
            bncRank: lookup?.bncRank ?? 0,
            frqRank: lookup?.frqRank ?? 0,
            now: now,
          );
          created++;
        } else {
          word = found;
          existing++;
          // Only refresh fields the user has not customised.
          if (!found.customized && enrichFromDictionary && dictionary != null) {
            final DictionaryEntry? lookup = await dictionary!.lookup(
              entry.word,
            );
            if (lookup != null) {
              word = await words.applyDictionaryInfo(
                word: found,
                phonetic: lookup.phonetic,
                partOfSpeech: lookup.partOfSpeech,
                translation: lookup.translation,
                definition: lookup.definition,
                examTags: lookup.examTags,
                bncRank: lookup.bncRank,
                frqRank: lookup.frqRank,
                now: now,
              );
            }
          }
        }
        await wordBooks.addWords(bookId, <String>[word.id], now: now);
      }
      linked = (await wordBooks.wordCount(bookId)) - before;
    });

    return ImportOutcome(
      created: created,
      existing: existing,
      linked: linked,
      duplicateInFile: preview.duplicateCount,
      invalid: preview.invalidCount,
    );
  }

  bool _looksLikeWord(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 48) return false;
    return RegExp(r"^[A-Za-z][A-Za-z'\-\. ]*$").hasMatch(trimmed);
  }

  String _bookNameFrom(String name) {
    final String base = name.split(RegExp(r'[/\\]')).last;
    final int dot = base.lastIndexOf('.');
    final String stem = dot > 0 ? base.substring(0, dot) : base;
    return stem.trim().isEmpty ? '导入词书' : stem.trim();
  }

  /// Minimal RFC-4180 style parser (quoted fields, escaped quotes, CRLF).
  List<List<String>> _parseCsvRows(String content) {
    final List<List<String>> rows = <List<String>>[];
    List<String> current = <String>[];
    final StringBuffer field = StringBuffer();
    bool inQuotes = false;

    void endField() {
      current.add(field.toString());
      field.clear();
    }

    void endRow() {
      endField();
      rows.add(current);
      current = <String>[];
    }

    for (int i = 0; i < content.length; i++) {
      final String char = content[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < content.length && content[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(char);
        }
        continue;
      }
      switch (char) {
        case '"':
          inQuotes = true;
        case ',':
          endField();
        case '\n':
          endRow();
        case '\r':
          break;
        default:
          field.write(char);
      }
    }
    if (field.isNotEmpty || current.isNotEmpty) endRow();
    return rows;
  }
}
