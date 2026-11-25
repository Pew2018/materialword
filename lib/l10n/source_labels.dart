import 'l10n.dart';

/// Localised name for a word's `source` column.
///
/// The column stores internal identifiers (`manual`, `import`, `url`, …). They
/// must never reach the interface: a user who imported a list should read
/// "Imported", not "import".
String wordSourceLabel(AppLocalizations l10n, String source) =>
    switch (source.trim().toLowerCase()) {
      'manual' => l10n.sourceManual,
      'import' => l10n.sourceImport,
      'file' => l10n.sourceFile,
      'url' => l10n.sourceUrl,
      'sample' => l10n.sourceSample,
      'dictionary' => l10n.sourceDictionary,
      _ => l10n.sourceOther,
    };
