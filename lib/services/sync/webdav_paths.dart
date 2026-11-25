/// Path model for a WebDAV target.
///
/// The provider used to derive every URL by string-editing the base address and
/// then walking *all* path segments of the result, which made `/dav/` look like
/// a directory the user owns. That is how a badly configured server ended up
/// answering `MKCOL /dav/ → 403`.
///
/// This class keeps the three concepts apart, permanently:
///
/// ```text
/// server base collection   https://dav.example.com/dav/     (never created)
/// user directory          MaterialWord                     (created when missing)
/// data file               materialword-data.json           (written, never created
///                                                           by probing)
/// ```
///
/// Rules encoded here (see `docs/phase6.2-webdav-compatibility.md`):
///  * the base collection's own path is preserved verbatim and is never a
///    creation target;
///  * `''`, `/`, `MaterialWord`, `/MaterialWord` and `/MaterialWord/` all resolve
///    to the same location;
///  * each segment is decoded once and re-encoded once, so an already
///    percent-encoded paste (`Material%20Word`) does not become `%2520`;
///  * `.`/`..`/empty segments and control characters are rejected, so neither a
///    directory name nor a file name can escape the base collection;
///  * an empty directory means "the base collection itself", not "the server
///    root".
library;

class WebDavPaths {
  WebDavPaths._({
    required this.base,
    required this.segments,
    required this.fileName,
  });

  /// Absolute base collection, always ending with `/`, never with credentials.
  final Uri base;

  /// Directory segments below [base], already decoded and canonical.
  final List<String> segments;

  /// Single path segment, already decoded and canonical.
  final String fileName;

  /// Refuses absurdly deep paths rather than generating 40 MKCOL requests.
  static const int maxDepth = 32;

  /// Longest single segment we accept (most servers cap at 255 bytes).
  static const int maxSegmentLength = 255;

  /// Returns null when the configuration cannot describe a safe location.
  static WebDavPaths? resolve({
    required String baseUrl,
    required String remoteDir,
    required String fileName,
  }) {
    Uri parsed;
    try {
      parsed = Uri.parse(baseUrl.trim());
    } on FormatException {
      return null;
    }
    if (!parsed.hasScheme || parsed.host.isEmpty) return null;
    final String scheme = parsed.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return null;
    // Credentials belong in the Authorization header, never in a URL that ends
    // up in a log line.
    if (parsed.userInfo.isNotEmpty) return null;
    if (parsed.hasQuery || parsed.hasFragment) return null;

    // Rebuild the base path segment by segment: `pathSegments` decodes, so
    // `Uri.encodeComponent` produces the canonical single-encoded form.
    final List<String> baseSegments = parsed.pathSegments
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
    if (baseSegments.length + maxDepth > 4096) return null;

    final String basePath = baseSegments.isEmpty
        ? '/'
        : '/${baseSegments.map(Uri.encodeComponent).join('/')}/';
    final Uri base = parsed.replace(path: basePath);

    final List<String> dirSegments = <String>[];
    for (final String raw in remoteDir.split(RegExp(r'[/\\]'))) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final String? segment = _canonicalSegment(trimmed);
      if (segment == null) return null;
      dirSegments.add(segment);
      if (dirSegments.length > maxDepth) return null;
    }

    final String? file = _canonicalSegment(fileName.trim());
    if (file == null) return null;

    return WebDavPaths._(base: base, segments: dirSegments, fileName: file);
  }

  /// Decodes once, rejects dangerous values, encodes once.
  static String? _canonicalSegment(String raw) {
    String decoded;
    try {
      decoded = Uri.decodeComponent(raw);
    } on ArgumentError {
      // A lone `%` is not an escape sequence; treat it as a literal character.
      decoded = raw;
    } on FormatException {
      decoded = raw;
    }
    if (decoded.isEmpty) return null;
    if (decoded == '.' || decoded == '..') return null;
    if (decoded.length > maxSegmentLength) return null;
    for (final int unit in decoded.codeUnits) {
      // Control characters break request lines and log files alike.
      if (unit < 0x20 || unit == 0x7f) return null;
    }
    if (decoded.contains('/') || decoded.contains('\\')) return null;
    return decoded;
  }

  /// `/dav/` — the collection users configure. Never a creation target.
  String get basePath => base.path;

  /// Decoded directory path relative to the base collection (`''` = base).
  String get relativeDirectory => segments.join('/');

  /// User-facing absolute-ish path, e.g. `/dav/MaterialWord/`.
  String get directoryPath => segments.isEmpty
      ? basePath
      : '$basePath${segments.map(_encode).join('/')}/';

  Uri get directoryUri => base.replace(
    path: segments.isEmpty
        ? basePath
        : '$basePath${segments.map(_encode).join('/')}/',
  );

  Uri get fileUri =>
      directoryUri.replace(path: '${directoryUri.path}${_encode(fileName)}');

  /// The collection [depth] levels below the base (`1..segments.length`).
  Uri directoryAt(int depth) {
    final int clamped = depth.clamp(0, segments.length);
    return base.replace(
      path: clamped == 0
          ? basePath
          : '$basePath${segments.take(clamped).map(_encode).join('/')}/',
    );
  }

  /// Child collection by name, refusing anything that is not a single segment.
  Uri? childDirectory(String name) {
    final String? segment = _canonicalSegment(name.trim());
    if (segment == null) return null;
    final String prefix = directoryPath;
    return base.replace(path: '$prefix${_encode(segment)}/');
  }

  /// Collection for a decoded path relative to [base] (`''` = the base itself).
  ///
  /// Used by the directory browser, which navigates inside the base collection
  /// rather than inside the configured data folder.
  Uri? collectionForPath(String relative) {
    final List<String> parts = <String>[];
    for (final String raw in relative.split(RegExp(r'[/\\]'))) {
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final String? segment = _canonicalSegment(trimmed);
      if (segment == null) return null;
      parts.add(_encode(segment));
      if (parts.length > maxDepth) return null;
    }
    return base.replace(
      path: parts.isEmpty ? basePath : '$basePath${parts.join('/')}/',
    );
  }

  static String _encode(String decoded) => Uri.encodeComponent(decoded);

  /// Maps a PROPFIND/`Location` href back to a decoded path relative to [base].
  ///
  /// Returns null for another origin (a redirect or a misbehaving server must
  /// never make us list — or write to — a different host) and for paths outside
  /// the configured base collection.
  String? relativePathOf(Uri resolved) {
    if (resolved.origin != base.origin) return null;
    final List<String> baseSegments = base.pathSegments
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
    final List<String> candidate = resolved.pathSegments
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
    if (candidate.length < baseSegments.length) return null;
    for (int i = 0; i < baseSegments.length; i++) {
      if (candidate[i] != baseSegments[i]) return null;
    }
    return candidate.skip(baseSegments.length).join('/');
  }

  /// Resolves `href` from a response body against the request that produced it.
  Uri? resolveHref(String href, Uri requested) {
    final String trimmed = href.trim();
    if (trimmed.isEmpty) return null;
    try {
      return requested.resolve(trimmed);
    } on FormatException {
      return null;
    }
  }
}
