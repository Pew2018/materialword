/// Build-level facts shown in 设置 → 关于 and embedded in diagnostics reports.
///
/// [appVersion] must stay in sync with `pubspec.yaml`; [buildCommit] is supplied
/// by CI (`--dart-define=GIT_COMMIT=<sha>`) so an exported report can be tied to
/// the exact source that produced the binary.
library;

const String appVersion = '1.2.0';

const String buildCommit = String.fromEnvironment(
  'GIT_COMMIT',
  defaultValue: 'local-build',
);

/// Entries in `assets/dictionary/ecdict_core.db`, from its `.meta.json`.
/// Kept as a constant so the About page never has to open the dictionary.
const int dictionaryEntryCount = 57835;

const String dictionaryLicense = 'MIT';
