import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart'
    show QueryRow, ResultSetImplementation, Variable;
import 'package:http/http.dart' as http;

import '../core/database/app_database.dart';
import '../core/repositories/word_repository.dart';
import '../core/repositories/wordbook_repository.dart';
import '../core/text/dictionary_text.dart';
import 'dictionary_service.dart';
import 'word_intake_service.dart';

/// One parsed row coming from a TXT / CSV / JSON file.
///
/// Use [ParsedEntry.clean] for anything that comes from a dictionary export:
/// it normalises literal `\n` escapes, CRLF and stray blank lines while leaving
/// the user's own note untouched.
class ParsedEntry {
  const ParsedEntry({
    required this.word,
    this.phonetic = '',
    this.partOfSpeech = '',
    this.translation = '',
    this.definition = '',
    this.example = '',
    this.phrase = '',
    this.note = '',
    this.examTags = '',
    this.bncRank = 0,
    this.frqRank = 0,
  });

  factory ParsedEntry.clean({
    required String word,
    String phonetic = '',
    String partOfSpeech = '',
    String translation = '',
    String definition = '',
    String example = '',
    String phrase = '',
    String note = '',
    String examTags = '',
    int bncRank = 0,
    int frqRank = 0,
  }) {
    return ParsedEntry(
      word: word.trim(),
      phonetic: normalizeDictionaryText(phonetic),
      partOfSpeech: normalizeDictionaryText(partOfSpeech),
      translation: normalizeDictionaryText(translation),
      definition: normalizeDictionaryText(definition),
      example: normalizeDictionaryText(example),
      phrase: normalizeDictionaryText(phrase),
      note: note,
      examTags: examTags.trim(),
      bncRank: bncRank,
      frqRank: frqRank,
    );
  }

  final String word;
  final String phonetic;
  final String partOfSpeech;
  final String translation;
  final String definition;
  final String example;
  final String phrase;
  final String note;
  final String examTags;
  final int bncRank;
  final int frqRank;

  String get key => normalizeWordKey(word);

  /// True when the row carries anything beyond the bare word, i.e. the file is
  /// authoritative content rather than a plain spelling list.
  bool get hasContent =>
      phonetic.trim().isNotEmpty ||
      partOfSpeech.trim().isNotEmpty ||
      translation.trim().isNotEmpty ||
      definition.trim().isNotEmpty ||
      example.trim().isNotEmpty ||
      phrase.trim().isNotEmpty ||
      note.trim().isNotEmpty ||
      examTags.trim().isNotEmpty;

  WordContent get content => WordContent(
    phonetic: phonetic,
    partOfSpeech: partOfSpeech,
    translation: translation,
    definition: definition,
    example: example,
    phrase: phrase,
    note: note,
  );
}

class ImportIssue {
  const ImportIssue(this.line, this.reason);

  final String line;
  final String reason;
}

/// Intermediate parse result for a JSON row list.
class _ParsedNodes {
  const _ParsedNodes({
    required this.entries,
    required this.invalid,
    required this.rows,
    required this.issues,
  });

  final List<ParsedEntry> entries;
  final int invalid;
  final int rows;
  final List<ImportIssue> issues;
}

/// One book inside a preview. A plain TXT / CSV file has exactly one unnamed
/// section; a MaterialWord word-book JSON may carry several.
class ImportSection {
  const ImportSection({
    required this.name,
    this.description = '',
    required this.entries,
  });

  final String name;
  final String description;
  final List<ParsedEntry> entries;
}

/// Everything the confirmation dialog needs before touching the database.
class ImportPreview {
  const ImportPreview({
    required this.sections,
    required this.format,
    required this.detectedBookName,
    this.duplicateCount = 0,
    this.invalidCount = 0,
    this.totalRows = 0,
    this.issues = const <ImportIssue>[],
    this.sourceUrl = '',
    this.sourceName = '',
    this.contentHash = '',
    this.dictionaryEnrichable = true,
  });

  /// Backwards-compatible constructor for single-book previews.
  factory ImportPreview.single({
    required List<ParsedEntry> entries,
    required String format,
    required String detectedBookName,
    int duplicateCount = 0,
    int invalidCount = 0,
    int totalRows = 0,
    List<ImportIssue> issues = const <ImportIssue>[],
    String sourceUrl = '',
    String sourceName = '',
    String contentHash = '',
    bool dictionaryEnrichable = true,
  }) => ImportPreview(
    sections: <ImportSection>[
      ImportSection(name: detectedBookName, entries: entries),
    ],
    format: format,
    detectedBookName: detectedBookName,
    duplicateCount: duplicateCount,
    invalidCount: invalidCount,
    totalRows: totalRows,
    issues: issues,
    sourceUrl: sourceUrl,
    sourceName: sourceName,
    contentHash: contentHash,
    dictionaryEnrichable: dictionaryEnrichable,
  );

  final List<ImportSection> sections;
  final String format;
  final String detectedBookName;
  final int duplicateCount;
  final int invalidCount;

  /// Rows the file contained after header removal, including invalid ones and
  /// rows beyond the entry limit. Used to prove nothing was silently dropped.
  final int totalRows;
  final List<ImportIssue> issues;
  final String sourceUrl;
  final String sourceName;

  /// sha256 over the normalised rows. A stale preview (same object, different
  /// file) can be detected instead of importing the wrong content.
  final String contentHash;

  /// False for formats that carry no missing fields (TXT is a bare word list),
  /// so the caller does not waste time on dictionary lookups.
  final bool dictionaryEnrichable;

  List<ParsedEntry> get entries => <ParsedEntry>[
    for (final ImportSection section in sections) ...section.entries,
  ];

  int get validCount => entries.length;

  int get sectionCount => sections.length;

  bool get multiBook => sections.length > 1;

  bool get isEmpty => entries.isEmpty && invalidCount == 0;

  /// How many rows the file had that are *not* in [entries] (invalid or over the
  /// limit). The UI must show this instead of pretending the whole file loaded.
  int get droppedRows => math.max(0, totalRows - entries.length);
}

/// Counts computed against the local database before committing. Read-only: the
/// preview phase never writes learning data.
class ImportPreviewStats {
  const ImportPreviewStats({
    required this.total,
    required this.newWords,
    required this.existingWords,
    required this.restorableWords,
    required this.linkAdds,
    required this.duplicateInFile,
    required this.invalid,
    required this.droppedRows,
  });

  final int total;
  final int newWords;
  final int existingWords;

  /// Words that exist locally as tombstones and would be restored by a normal
  /// import (never by an automatic refresh).
  final int restorableWords;
  final int linkAdds;
  final int duplicateInFile;
  final int invalid;
  final int droppedRows;
}

class ImportOutcome {
  const ImportOutcome({
    required this.created,
    required this.existing,
    required this.linked,
    required this.duplicateInFile,
    required this.invalid,
    this.revived = 0,
    this.updated = 0,
    this.unchanged = 0,
    this.skippedDeleted = 0,
    this.books = 1,
    this.bookId,
  });

  final int created;
  final int existing;
  final int linked;
  final int duplicateInFile;
  final int invalid;

  /// Restored tombstones and how many of the existing rows were actually
  /// modified. Reported separately so "imported" never hides a no-op.
  final int revived;
  final int updated;
  final int unchanged;
  final int skippedDeleted;
  final int books;
  final String? bookId;

  String get summary {
    final List<String> parts = <String>[
      '新增 $created 个词条',
      if (revived > 0) '恢复 $revived 个已删除词条',
      '已存在 $existing 个',
      if (updated > 0) '更新 $updated 个',
      '关联 $linked 个到词书',
      if (books > 1) '涉及 $books 个词书',
      if (skippedDeleted > 0) '跳过 $skippedDeleted 个已删除词条（在线刷新不自动恢复）',
      if (duplicateInFile > 0) '文件内重复 $duplicateInFile 个',
      if (invalid > 0) '忽略无效 $invalid 行',
    ];
    return parts.join('，');
  }
}

/// Raised when the user cancels a download or a long parse.
class ImportCancelledException implements Exception {
  const ImportCancelledException();

  @override
  String toString() => '已取消';
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
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration readTimeout = Duration(seconds: 20);
  static const int maxRedirects = 3;

  /// Highest word-book exchange protocol this build writes/reads. Version 1 was
  /// the bare word array, version 2 adds book metadata, phrase and exam tags.
  static const int wordBookExchangeVersion = 2;

  bool _cancelled = false;

  /// Cancels the download/parse currently in flight. The next call resets it.
  void cancel() => _cancelled = true;

  WordIntakeService get _intake =>
      WordIntakeService(db: words.db, words: words, wordBooks: wordBooks);

  // ------------------------------------------------------------- file input

  Future<ImportPreview> parseFile(String path, {String? fileName}) async {
    final File file = File(path);
    if (!file.existsSync()) {
      throw const FormatException('文件不存在或已被移动');
    }
    final int length = await file.length();
    if (length > maxFileBytes) {
      throw FormatException(
        '文件过大（${_mb(length)}，上限 ${_mb(maxFileBytes)}），请拆分后再导入',
      );
    }
    return parseBytes(
      await file.readAsBytes(),
      name: fileName ?? path.split(Platform.pathSeparator).last,
    );
  }

  /// Parses raw bytes with a **strict** UTF-8 decode. Silently replacing broken
  /// bytes would corrupt the user's words, so a bad encoding is reported and the
  /// user can cancel instead.
  ImportPreview parseBytes(List<int> bytes, {required String name}) {
    final List<int> data = bytes;
    if (data.length > maxFileBytes) {
      throw FormatException('文件过大（上限 ${_mb(maxFileBytes)}）');
    }
    if (data.length >= 2) {
      final bool utf16 =
          (data[0] == 0xFF && data[1] == 0xFE) ||
          (data[0] == 0xFE && data[1] == 0xFF);
      if (utf16) {
        throw const FormatException('文件是 UTF-16 编码，请另存为 UTF-8 后再导入');
      }
    }
    String content;
    try {
      content = const Utf8Decoder(allowMalformed: false).convert(data);
    } on FormatException {
      throw const FormatException('文件不是有效的 UTF-8 编码（可能含有损坏字符），请转换编码后重试');
    }
    final String format = _detectFormat(name, content);
    return parseContent(content, format: format, name: name);
  }

  // ------------------------------------------------------------- URL input

  http.Client? _client;

  /// Downloads an online word list with a **streaming** byte cap.
  ///
  /// The old implementation buffered the whole response and only then compared
  /// `content.length`, so a hostile or broken server could exhaust memory and
  /// the 8 MB limit was measured in UTF-16 code units, not bytes.
  Future<ImportPreview> fetchUrl(
    String url, {
    http.Client? client,
    void Function(int received)? onProgress,
  }) async {
    _cancelled = false;
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('请输入完整的 HTTPS 地址');
    }
    if (uri.scheme != 'https') {
      throw const FormatException('只支持 HTTPS 地址（不会关闭 TLS 证书校验）');
    }
    if (uri.host.isEmpty) throw const FormatException('地址缺少主机名');
    if (uri.userInfo.isNotEmpty) {
      throw const FormatException('地址不能包含用户名或密码，请改用无需认证的链接');
    }
    final http.Client httpClient = client ?? (_client ??= http.Client());
    try {
      final http.StreamedResponse response = await _open(httpClient, uri);
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw FormatException('下载失败：HTTP ${response.statusCode}');
      }
      final int? declared = response.contentLength;
      if (declared != null && declared > maxFileBytes) {
        await response.stream.drain<void>();
        throw FormatException('下载内容过大（上限 ${_mb(maxFileBytes)}），已停止下载');
      }
      final BytesBuilder builder = BytesBuilder(copy: false);
      try {
        await for (final List<int> chunk in response.stream.timeout(
          readTimeout,
        )) {
          if (_cancelled) throw const ImportCancelledException();
          builder.add(chunk);
          onProgress?.call(builder.length);
          if (builder.length > maxFileBytes) {
            throw FormatException('下载内容超过 ${_mb(maxFileBytes)}，已提前终止（未写入任何数据）');
          }
        }
      } on TimeoutException {
        throw const FormatException('下载超时，请检查网络后重试');
      }
      final Uri finalUri = response.request?.url ?? uri;
      final String name = finalUri.pathSegments.isEmpty
          ? '在线词表'
          : finalUri.pathSegments.last;
      final ImportPreview preview = parseBytes(builder.takeBytes(), name: name);
      return ImportPreview(
        sections: preview.sections,
        format: preview.format,
        detectedBookName: preview.detectedBookName,
        duplicateCount: preview.duplicateCount,
        invalidCount: preview.invalidCount,
        totalRows: preview.totalRows,
        issues: preview.issues,
        sourceUrl: finalUri.toString(),
        sourceName: name,
        contentHash: preview.contentHash,
        dictionaryEnrichable: preview.dictionaryEnrichable,
      );
    } on FormatException {
      rethrow;
    } on ImportCancelledException {
      rethrow;
    } on http.ClientException catch (e) {
      throw FormatException('下载失败：${e.message}');
    } finally {
      if (client == null) {
        _client?.close();
        _client = null;
      }
    }
  }

  /// Follows at most [maxRedirects] HTTPS redirects and returns the final
  /// response. A downgrade to plain HTTP is refused, and no credential is ever
  /// attached (online word books are public documents).
  Future<http.StreamedResponse> _open(http.Client client, Uri uri) async {
    Uri current = uri;
    for (int hop = 0; hop <= maxRedirects; hop++) {
      final http.StreamedResponse response = await client
          .send(
            http.Request('GET', current)
              ..followRedirects = false
              ..headers['User-Agent'] = 'MaterialWord',
          )
          .timeout(connectTimeout);
      final bool redirect =
          response.statusCode >= 300 && response.statusCode < 400;
      if (!redirect) return response;
      final String? location = response.headers['location'];
      await response.stream.drain<void>();
      if (location == null) {
        throw const FormatException('服务器返回了缺少 Location 的重定向');
      }
      final Uri next = current.resolve(location);
      if (next.scheme != 'https') {
        throw const FormatException('服务器重定向到非 HTTPS 地址，已拒绝');
      }
      current = next;
    }
    throw const FormatException('重定向次数过多，已停止下载');
  }

  void dispose() {
    _client?.close();
    _client = null;
  }

  // --------------------------------------------------------------- parsing

  String _detectFormat(String name, String content) {
    final String lower = name.toLowerCase();
    final String trimmed = content.trimLeft();
    final bool looksJson = trimmed.startsWith('{') || trimmed.startsWith('[');
    final bool looksCsv = trimmed
        .split('\n')
        .first
        .toLowerCase()
        .replaceAll(' ', '')
        .contains('word,');
    if (lower.endsWith('.json')) {
      if (!looksJson && trimmed.isNotEmpty) {
        throw const FormatException('文件扩展名是 .json，但内容不是 JSON。请检查是否选错了文件');
      }
      return 'json';
    }
    if (lower.endsWith('.csv')) {
      if (looksJson) {
        throw const FormatException('文件扩展名是 .csv，但内容是 JSON。请改名为 .json 后重试');
      }
      return 'csv';
    }
    if (lower.endsWith('.txt')) {
      if (looksJson) {
        throw const FormatException('文件扩展名是 .txt，但内容是 JSON。请改名为 .json 后重试');
      }
      return 'txt';
    }
    if (looksJson) return 'json';
    if (looksCsv) return 'csv';
    return 'txt';
  }

  ImportPreview parseContent(
    String rawContent, {
    required String format,
    String name = 'import',
  }) {
    _cancelled = false;
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
    int rows = 0;
    final List<String> lines = const LineSplitter().convert(content);

    for (final String rawLine in lines) {
      if (_cancelled) throw const ImportCancelledException();
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      rows++;
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
      final ParsedEntry entry = ParsedEntry.clean(
        word: word,
        translation: parts.length > 1 ? parts.sublist(1).join(' ').trim() : '',
      );
      if (!seen.add(entry.key)) {
        duplicate++;
        continue;
      }
      entries.add(entry);
    }
    _rejectOverLimit(entries.length);
    return ImportPreview.single(
      entries: entries,
      format: 'txt',
      detectedBookName: _bookNameFrom(name),
      duplicateCount: duplicate,
      invalidCount: invalid,
      totalRows: rows,
      issues: issues,
      sourceName: name,
      contentHash: _hashEntries(entries),
      dictionaryEnrichable: true,
    );
  }

  ImportPreview _parseCsv(String content, String name) {
    final List<List<String>> rows = _parseCsvRows(content);
    if (rows.isEmpty) {
      return ImportPreview.single(
        entries: const <ParsedEntry>[],
        format: 'csv',
        detectedBookName: _bookNameFrom(name),
        sourceName: name,
      );
    }
    final List<String> header = rows.first.map(_normalizeHeader).toList();
    int column(List<String> keys) {
      for (final String key in keys) {
        final int index = header.indexOf(key);
        if (index >= 0) return index;
      }
      return -1;
    }

    final int wordIndex = column(<String>['word']);
    if (wordIndex < 0) {
      throw const FormatException('CSV 缺少必需的 word 列');
    }
    // Accept every alias this project has ever written, including the
    // `partOfSpeech` header produced by its own exporter (phase 5D-01).
    final int phoneticIndex = column(<String>['phonetic']);
    final int posIndex = column(<String>[
      'partofspeech',
      'part_of_speech',
      'pos',
    ]);
    final int translationIndex = column(<String>['translation', 'meaning']);
    final int definitionIndex = column(<String>['definition']);
    final int exampleIndex = column(<String>['example', 'sentence']);
    final int phraseIndex = column(<String>['phrase']);
    final int noteIndex = column(<String>['note']);
    final int examTagsIndex = column(<String>['examtags', 'exam_tags', 'tags']);
    final int bookIndex = column(<String>['book', 'wordbook', 'bookname']);

    String cell(List<String> row, int index) =>
        index >= 0 && index < row.length ? row[index].trim() : '';

    final List<ParsedEntry> entries = <ParsedEntry>[];
    final Set<String> seen = <String>{};
    final List<ImportIssue> issues = <ImportIssue>[];
    final Map<String, List<ParsedEntry>> byBook = <String, List<ParsedEntry>>{};
    final String fallbackName = _bookNameFrom(name);
    int duplicate = 0;
    int invalid = 0;
    int rowCount = 0;

    for (int i = 1; i < rows.length; i++) {
      if (_cancelled) throw const ImportCancelledException();
      final List<String> row = rows[i];
      if (row.every((String c) => c.trim().isEmpty)) continue;
      rowCount++;
      final String word = cell(row, wordIndex);
      if (!_looksLikeWord(word)) {
        invalid++;
        if (issues.length < 20) {
          issues.add(ImportIssue(row.join(','), '第 ${i + 1} 行 word 无效'));
        }
        continue;
      }
      final ParsedEntry entry = ParsedEntry.clean(
        word: word,
        phonetic: cell(row, phoneticIndex),
        partOfSpeech: cell(row, posIndex),
        translation: cell(row, translationIndex),
        definition: cell(row, definitionIndex),
        example: cell(row, exampleIndex),
        phrase: cell(row, phraseIndex),
        note: cell(row, noteIndex),
        examTags: cell(row, examTagsIndex),
      );
      if (!seen.add(entry.key)) {
        duplicate++;
        continue;
      }
      entries.add(entry);
      final String book = cell(row, bookIndex);
      (byBook[book.isEmpty ? fallbackName : book] ??= <ParsedEntry>[]).add(
        entry,
      );
    }
    _rejectOverLimit(entries.length);
    // A row without a `book` cell belongs to the file-named book, never to
    // "nowhere": otherwise a multi-book CSV would drop those rows.
    if (byBook.isEmpty) byBook[fallbackName] = entries;
    final List<ImportSection> sections = byBook.length <= 1
        ? <ImportSection>[ImportSection(name: fallbackName, entries: entries)]
        : <ImportSection>[
            for (final MapEntry<String, List<ParsedEntry>> group
                in byBook.entries)
              ImportSection(name: group.key, entries: group.value),
          ];
    return ImportPreview(
      sections: sections,
      format: 'csv',
      detectedBookName: _bookNameFrom(name),
      duplicateCount: duplicate,
      invalidCount: invalid,
      totalRows: rowCount,
      issues: issues,
      sourceName: name,
      contentHash: _hashEntries(entries),
      dictionaryEnrichable: true,
    );
  }

  ImportPreview _parseJson(String content, String name) {
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (e) {
      throw FormatException('JSON 格式错误：${e.message}');
    }
    String bookName = _bookNameFrom(name);
    String description = '';
    List<dynamic> rawWords = const <dynamic>[];
    final List<ImportSection> sections = <ImportSection>[];
    int invalid = 0;
    int totalRows = 0;
    final List<ImportIssue> issues = <ImportIssue>[];

    void absorb(_ParsedNodes parsed) {
      invalid += parsed.invalid;
      totalRows += parsed.rows;
      issues.addAll(parsed.issues);
    }

    if (decoded is Map<String, dynamic>) {
      if (decoded['kind'] == 'materialword-backup') {
        throw const FormatException(
          '这是完整学习备份（含学习记录），请到「设置 → 备份与恢复」导入，不要作为词书导入',
        );
      }
      final Object? version = decoded['schemaVersion'];
      if (version is int && version > wordBookExchangeVersion) {
        throw const FormatException('词书文件版本过新，请升级应用后再导入');
      }
      final Object? declaredName = decoded['name'] ?? decoded['bookName'];
      if (declaredName is String && declaredName.trim().isNotEmpty) {
        bookName = declaredName.trim();
      }
      final Object? declaredDescription = decoded['description'];
      if (declaredDescription is String) description = declaredDescription;
      final Object? booksNode = decoded['books'];
      final Object? wordsNode = decoded['words'] ?? decoded['entries'];
      if (booksNode is List<dynamic>) {
        for (final dynamic bookNode in booksNode) {
          if (bookNode is! Map<String, dynamic>) {
            throw const FormatException('JSON books 数组的元素必须是对象');
          }
          final Object? sectionWords = bookNode['words'] ?? bookNode['entries'];
          if (sectionWords is! List<dynamic>) {
            throw const FormatException('JSON 词书缺少 words 数组');
          }
          final _ParsedNodes parsed = _entriesFromNodes(sectionWords);
          absorb(parsed);
          final Object? sectionName = bookNode['name'];
          sections.add(
            ImportSection(
              name: sectionName is String && sectionName.trim().isNotEmpty
                  ? sectionName.trim()
                  : bookName,
              description: (bookNode['description'] as String?) ?? '',
              entries: parsed.entries,
            ),
          );
        }
      } else if (wordsNode is List<dynamic>) {
        rawWords = wordsNode;
      } else {
        throw const FormatException('JSON 缺少 words 数组');
      }
    } else if (decoded is List<dynamic>) {
      rawWords = decoded;
    } else {
      throw const FormatException('无法识别的 JSON 结构');
    }

    if (sections.isEmpty) {
      final _ParsedNodes parsed = _entriesFromNodes(rawWords);
      absorb(parsed);
      sections.add(
        ImportSection(
          name: bookName,
          description: description,
          entries: parsed.entries,
        ),
      );
    }

    final List<ParsedEntry> all = <ParsedEntry>[
      for (final ImportSection section in sections) ...section.entries,
    ];
    final Set<String> seen = <String>{};
    int duplicate = 0;
    for (final ParsedEntry entry in all) {
      if (!seen.add(entry.key)) duplicate++;
    }
    final List<ImportSection> normalized = <ImportSection>[
      for (final ImportSection section in sections)
        ImportSection(
          name: section.name,
          description: section.description,
          entries: _dedupe(section.entries),
        ),
    ];
    _rejectOverLimit(
      normalized.fold<int>(
        0,
        (int sum, ImportSection section) => sum + section.entries.length,
      ),
    );
    return ImportPreview(
      sections: normalized,
      format: 'json',
      detectedBookName: normalized.isEmpty ? bookName : normalized.first.name,
      duplicateCount: duplicate,
      invalidCount: invalid,
      totalRows: totalRows,
      issues: issues,
      sourceName: name,
      contentHash: _hashEntries(all),
      dictionaryEnrichable: true,
    );
  }

  List<ParsedEntry> _dedupe(List<ParsedEntry> entries) {
    final Set<String> seen = <String>{};
    return <ParsedEntry>[
      for (final ParsedEntry entry in entries)
        if (seen.add(entry.key)) entry,
    ];
  }

  _ParsedNodes _entriesFromNodes(List<dynamic> nodes) {
    final List<ParsedEntry> entries = <ParsedEntry>[];
    final List<ImportIssue> issues = <ImportIssue>[];
    int invalid = 0;
    int seenRows = 0;
    for (final dynamic node in nodes) {
      if (_cancelled) throw const ImportCancelledException();
      seenRows++;
      String word = '';
      String phonetic = '';
      String pos = '';
      String translation = '';
      String definition = '';
      String example = '';
      String phrase = '';
      String note = '';
      String examTags = '';
      int bncRank = 0;
      int frqRank = 0;
      if (node is String) {
        word = node;
      } else if (node is Map<String, dynamic>) {
        word = (node['word'] ?? node['name'] ?? '').toString();
        phonetic = (node['phonetic'] ?? '').toString();
        pos =
            (node['pos'] ??
                    node['partOfSpeech'] ??
                    node['part_of_speech'] ??
                    '')
                .toString();
        translation = (node['translation'] ?? node['meaning'] ?? '').toString();
        definition = (node['definition'] ?? '').toString();
        example = (node['example'] ?? node['sentence'] ?? '').toString();
        phrase = (node['phrase'] ?? '').toString();
        note = (node['note'] ?? '').toString();
        final Object? tags = node['examTags'] ?? node['exam_tags'];
        if (tags is List) {
          examTags = tags
              .map((Object? t) => '$t'.trim())
              .where((String t) => t.isNotEmpty)
              .join(' ');
        } else if (tags != null) {
          examTags = tags.toString();
        }
        final Object? bnc = node['bncRank'] ?? node['bnc'];
        final Object? frq = node['frqRank'] ?? node['frq'];
        bncRank = bnc is int ? bnc : int.tryParse('${bnc ?? ''}') ?? 0;
        frqRank = frq is int ? frq : int.tryParse('${frq ?? ''}') ?? 0;
      } else {
        invalid++;
        if (issues.length < 20) {
          issues.add(ImportIssue('$node', '无效词条（应为字符串或对象）'));
        }
        continue;
      }
      if (!_looksLikeWord(word)) {
        invalid++;
        if (issues.length < 20) {
          issues.add(ImportIssue(word.isEmpty ? '(空)' : word, '无效词条'));
        }
        continue;
      }
      entries.add(
        ParsedEntry.clean(
          word: word,
          phonetic: phonetic,
          partOfSpeech: pos,
          translation: translation,
          definition: definition,
          example: example,
          phrase: phrase,
          note: note,
          examTags: examTags,
          bncRank: bncRank,
          frqRank: frqRank,
        ),
      );
    }
    return _ParsedNodes(
      entries: entries,
      invalid: invalid,
      rows: seenRows,
      issues: issues,
    );
  }

  /// Refuses to import more than [maxEntries] instead of silently stopping at
  /// the limit (which made a partial import look like a complete one).
  void _rejectOverLimit(int count) {
    if (count <= maxEntries) return;
    throw FormatException(
      '文件包含 $count 个单词，超过单次导入上限 $maxEntries 个。'
      '没有导入任何数据；请拆分为多个文件后分别导入',
    );
  }

  bool _looksLikeWord(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 64) return false;
    return RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ'\-\. ]*$")
        .hasMatch(trimmed);
  }

  String _bookNameFrom(String name) {
    final String base = name.split(RegExp(r'[/\\]')).last;
    final int dot = base.lastIndexOf('.');
    final String stem = dot > 0 ? base.substring(0, dot) : base;
    return stem.trim().isEmpty ? '导入词书' : stem.trim();
  }

  String _normalizeHeader(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

  String _hashEntries(List<ParsedEntry> entries) {
    final StringBuffer buffer = StringBuffer();
    for (final ParsedEntry entry in entries) {
      buffer
        ..write(entry.key)
        ..write('\u0001')
        ..write(entry.phonetic)
        ..write('\u0001')
        ..write(entry.partOfSpeech)
        ..write('\u0001')
        ..write(entry.translation)
        ..write('\u0001')
        ..write(entry.definition)
        ..write('\u0001')
        ..write(entry.example)
        ..write('\u0001')
        ..write(entry.phrase)
        ..write('\u0001')
        ..write(entry.note)
        ..write('\u0001')
        ..write(entry.examTags)
        ..write('\u0002');
    }
    return 'sha256:${sha256.convert(utf8.encode(buffer.toString()))}';
  }

  String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  /// Minimal RFC-4180 style parser (quoted fields, escaped quotes, CRLF).
  ///
  /// A field that never closes its quote is an error: the old parser silently
  /// swallowed the rest of the file into one cell.
  List<List<String>> _parseCsvRows(String content) {
    final List<List<String>> rows = <List<String>>[];
    List<String> current = <String>[];
    final StringBuffer field = StringBuffer();
    bool inQuotes = false;
    int line = 1;
    int quoteStartLine = 0;

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
          if (char == '\n') line++;
          field.write(char);
        }
        continue;
      }
      switch (char) {
        case '"':
          inQuotes = true;
          quoteStartLine = line;
        case ',':
          endField();
        case '\n':
          line++;
          endRow();
        case '\r':
          break;
        default:
          field.write(char);
      }
    }
    if (inQuotes) {
      throw FormatException('CSV 第 $quoteStartLine 行的引号没有闭合，文件可能已损坏');
    }
    if (field.isNotEmpty || current.isNotEmpty) endRow();
    return rows;
  }

  // ---------------------------------------------------------------- preview

  /// Counts what a commit would do, without writing anything. Read-only.
  Future<ImportPreviewStats> analyze(
    ImportPreview preview, {
    String? bookId,
  }) async {
    final List<String> keys = <String>[
      for (final ParsedEntry entry in preview.entries) entry.key,
    ];
    int existing = 0;
    int restorable = 0;
    int newWords = 0;
    final Map<String, bool> linked = <String, bool>{};
    for (int start = 0; start < keys.length; start += 400) {
      final List<String> chunk = keys.sublist(
        start,
        math.min(start + 400, keys.length),
      );
      final slots = List<String>.filled(chunk.length, '?').join(',');
      final List<QueryRow> rows = await words.db
          .customSelect(
            'SELECT normalized, deleted_at FROM words WHERE normalized IN ($slots)',
            variables: <Variable<Object>>[
              for (final String key in chunk) Variable<String>(key),
            ],
            readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
              words.db.words,
            },
          )
          .get();
      final Map<String, int?> byKey = <String, int?>{
        for (final QueryRow row in rows)
          row.read<String>('normalized'): row.readNullable<int>('deleted_at'),
      };
      for (final String key in chunk) {
        if (!byKey.containsKey(key)) {
          newWords++;
        } else if (byKey[key] != null) {
          existing++;
          restorable++;
        } else {
          existing++;
        }
      }
      if (bookId != null && chunk.isNotEmpty) {
        final List<QueryRow> links = await words.db
            .customSelect(
              'SELECT w.normalized AS normalized, e.deleted_at AS deleted_at '
              'FROM words w JOIN word_book_entries e ON e.word_id = w.id '
              'WHERE e.word_book_id = ? AND w.normalized IN ($slots)',
              variables: <Variable<Object>>[
                Variable<String>(bookId),
                for (final String key in chunk) Variable<String>(key),
              ],
              readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
                words.db.words,
                words.db.wordBookEntries,
              },
            )
            .get();
        for (final QueryRow row in links) {
          final String key = row.read<String>('normalized');
          final int? deletedAt = row.readNullable<int>('deleted_at');
          if (deletedAt == null) linked[key] = true;
        }
      }
    }
    final int linkAdds = bookId == null
        ? newWords + restorable
        : preview.entries
              .where((ParsedEntry entry) => linked[entry.key] != true)
              .map((ParsedEntry entry) => entry.key)
              .toSet()
              .length;
    return ImportPreviewStats(
      total: preview.validCount,
      newWords: newWords,
      existingWords: existing,
      restorableWords: restorable,
      linkAdds: linkAdds,
      duplicateInFile: preview.duplicateCount,
      invalid: preview.invalidCount,
      droppedRows: preview.droppedRows,
    );
  }

  // ----------------------------------------------------------------- commit

  /// Creates or resolves the target book **inside** the same transaction as the
  /// word writes, so a failed import cannot leave an empty book behind.
  ///
  /// Pass [bookId] to import into an existing book, or [newBookName] to create
  /// (or reuse, by name) a book. A multi-book JSON carries its own sections and
  /// ignores both.
  Future<ImportOutcome> commit({
    required ImportPreview preview,
    String? bookId,
    String? newBookName,
    String bookDescription = '',
    required DateTime now,
    bool enrichFromDictionary = true,
    bool allowRevive = true,
    String sourceType = 'file',
    String sourceUrl = '',
  }) async {
    _cancelled = false;
    final Map<String, DictionaryEntry?> lookups = await _lookups(
      preview,
      enrichFromDictionary: enrichFromDictionary,
    );
    int created = 0;
    int revived = 0;
    int existing = 0;
    int updated = 0;
    int unchanged = 0;
    int skippedDeleted = 0;
    int linked = 0;
    String? primaryBookId;

    await words.db.transaction(() async {
      final List<({ImportSection section, String targetBookId})> targets =
          <({ImportSection section, String targetBookId})>[];
      if (preview.multiBook) {
        for (final ImportSection section in preview.sections) {
          final String name = section.name.trim().isEmpty
              ? preview.detectedBookName
              : section.name;
          final WordBook book = await wordBooks.ensureBook(
            name: name,
            description: section.description,
            sourceType: sourceType,
            sourceUrl: sourceUrl,
            now: now,
          );
          targets.add((section: section, targetBookId: book.id));
        }
      } else {
        final ImportSection section = preview.sections.isEmpty
            ? const ImportSection(name: '', entries: <ParsedEntry>[])
            : preview.sections.first;
        String target;
        if (bookId != null) {
          final WordBook? book = await wordBooks.byId(bookId);
          if (book == null || book.deletedAt != null) {
            throw const WordIntakeException('目标词书已被删除，请重新选择词书后再导入');
          }
          target = book.id;
        } else {
          final String name = (newBookName ?? '').trim().isEmpty
              ? (section.name.trim().isEmpty
                    ? preview.detectedBookName
                    : section.name)
              : newBookName!.trim();
          final WordBook book = await wordBooks.ensureBook(
            name: name,
            description: section.description.isEmpty
                ? bookDescription
                : section.description,
            sourceType: sourceType,
            sourceUrl: sourceUrl,
            now: now,
          );
          target = book.id;
        }
        targets.add((section: section, targetBookId: target));
      }

      for (final ({ImportSection section, String targetBookId}) target
          in targets) {
        if (_cancelled) throw const ImportCancelledException();
        final List<WordIntakeRequest> requests = <WordIntakeRequest>[
          for (final ParsedEntry entry in target.section.entries)
            _requestFor(entry, lookups[entry.key], allowRevive: allowRevive),
        ];
        final List<WordIntakeResult> results = await _intake.addAll(
          requests,
          bookId: target.targetBookId,
          now: now,
        );
        for (final WordIntakeResult result in results) {
          switch (result.kind) {
            case IntakeKind.created:
              created++;
            case IntakeKind.revived:
              revived++;
              existing++;
            case IntakeKind.updated:
              updated++;
              existing++;
            case IntakeKind.unchanged:
              unchanged++;
              existing++;
            case IntakeKind.deletedSkipped:
              skippedDeleted++;
          }
          if (result.linkAdded) linked++;
        }
        primaryBookId ??= target.targetBookId;
      }
    });

    return ImportOutcome(
      created: created,
      existing: existing,
      linked: linked,
      duplicateInFile: preview.duplicateCount,
      invalid: preview.invalidCount,
      revived: revived,
      updated: updated,
      unchanged: unchanged,
      skippedDeleted: skippedDeleted,
      books: preview.multiBook ? preview.sectionCount : 1,
      bookId: primaryBookId ?? bookId,
    );
  }

  WordIntakeRequest _requestFor(
    ParsedEntry entry,
    DictionaryEntry? lookup, {
    required bool allowRevive,
  }) {
    return WordIntakeRequest(
      text: entry.word,
      content: entry.content,
      dictionary: lookup == null
          ? WordContent.empty
          : WordContent(
              phonetic: lookup.phonetic,
              partOfSpeech: lookup.partOfSpeech,
              translation: lookup.translation,
              definition: lookup.definition,
            ),
      source: 'import',
      examTags: entry.examTags.isNotEmpty
          ? entry.examTags
          : (lookup?.examTags ?? ''),
      bncRank: entry.bncRank != 0 ? entry.bncRank : (lookup?.bncRank ?? 0),
      frqRank: entry.frqRank != 0 ? entry.frqRank : (lookup?.frqRank ?? 0),
      allowRevive: allowRevive,
    );
  }

  /// Dictionary lookups happen **before** the write transaction: holding a
  /// write lock while querying a second SQLite file made big imports slower and
  /// blocked every other screen.
  Future<Map<String, DictionaryEntry?>> _lookups(
    ImportPreview preview, {
    required bool enrichFromDictionary,
  }) async {
    final Map<String, DictionaryEntry?> result = <String, DictionaryEntry?>{};
    final DictionaryService? service = dictionary;
    if (!enrichFromDictionary || service == null) return result;
    if (!preview.dictionaryEnrichable) return result;
    for (final ParsedEntry entry in preview.entries) {
      if (_cancelled) throw const ImportCancelledException();
      if (entry.phonetic.isNotEmpty &&
          entry.partOfSpeech.isNotEmpty &&
          entry.translation.isNotEmpty &&
          entry.definition.isNotEmpty) {
        continue;
      }
      try {
        result[entry.key] = await service.lookup(entry.word);
      } catch (_) {
        result[entry.key] = null;
      }
    }
    return result;
  }
}
