import '../core/time_utils.dart';
import '../services/backup_manager.dart';
import '../services/backup_service.dart';
import '../services/cloud_backup/cloud_backup_repository.dart';
import '../services/import_service.dart';
import 'l10n.dart';

/// Sentences about backups, merges and imports.
///
/// The services return counts ([MergeReport], [BackupInfo], [ImportOutcome]);
/// the wording is assembled here so the same result reads correctly in Chinese
/// and English, and so no service has to know about a language.

/// "12 words · 3 word lists · 12 links · 40 answers" — or why the file failed.
String backupInfoSummary(AppLocalizations l10n, BackupInfo info) {
  if (!info.valid) {
    return l10n.backupInfoUnreadable(info.problem ?? l10n.unknownReason);
  }
  final List<String> parts = <String>[
    l10n.backupInfoSummary(info.words, info.books, info.entries, info.events),
    if (info.tags > 0) l10n.backupInfoTags(info.tags),
    if (info.favorites > 0) l10n.backupInfoFavorites(info.favorites),
  ];
  return parts.join(' · ');
}

/// One line describing what a merge added, in the order the counts matter.
String mergeSummary(AppLocalizations l10n, MergeReport report) {
  final List<String> parts = <String>[
    l10n.mergeSummaryEvents(report.addedEvents),
    if (report.duplicateEvents > 0)
      l10n.mergeSummaryDuplicates(report.duplicateEvents),
    if (report.newWords > 0) l10n.mergeSummaryNewWords(report.newWords),
    if (report.updatedWords > 0)
      l10n.mergeSummaryUpdatedWords(report.updatedWords),
    if (report.deletedWords > 0)
      l10n.mergeSummaryDeletedWords(report.deletedWords),
    if (report.newBooks > 0) l10n.mergeSummaryNewBooks(report.newBooks),
    if (report.newEntries > 0) l10n.mergeSummaryNewEntries(report.newEntries),
    if (report.removedEntries > 0)
      l10n.mergeSummaryRemovedEntries(report.removedEntries),
    if (report.rebuiltStates > 0)
      l10n.mergeSummaryRebuiltStates(report.rebuiltStates),
    if (report.metadataUpdates > 0)
      l10n.mergeSummaryMetadata(report.metadataUpdates),
    if (report.conflicts > 0) l10n.mergeSummaryConflicts(report.conflicts),
  ];
  return parts.join(l10n.importOutcomeSeparator);
}

/// What a point-in-time restore replaced, and that a safety copy exists.
String restoreSummary(AppLocalizations l10n, RestoreOutcome outcome) =>
    l10n.restoreSummary(
      outcome.report.newWords + outcome.report.updatedWords,
      outcome.report.addedEvents,
    );

/// What an import actually did, including the parts it did not do.
String importOutcomeSummary(AppLocalizations l10n, ImportOutcome outcome) {
  final List<String> parts = <String>[
    l10n.importOutcomeCreated(outcome.created),
    if (outcome.revived > 0) l10n.importOutcomeRevived(outcome.revived),
    l10n.importOutcomeExisting(outcome.existing),
    if (outcome.updated > 0) l10n.importOutcomeUpdated(outcome.updated),
    l10n.importOutcomeLinked(outcome.linked),
    if (outcome.books > 1) l10n.importOutcomeBooks(outcome.books),
    if (outcome.skippedDeleted > 0)
      l10n.importOutcomeSkippedDeleted(outcome.skippedDeleted),
    if (outcome.duplicateInFile > 0)
      l10n.importOutcomeDuplicates(outcome.duplicateInFile),
    if (outcome.invalid > 0) l10n.importOutcomeInvalid(outcome.invalid),
  ];
  return parts.join(l10n.importOutcomeSeparator);
}

/// Why one line of an import file was skipped, in the interface language.
String describeImportIssue(AppLocalizations l10n, ImportIssue issue) =>
    switch (issue.code) {
      ImportIssueCode.notEnglishWord => l10n.importIssueNotEnglish,
      ImportIssueCode.rowWordInvalid => l10n.importIssueRowInvalid(
        issue.row ?? 0,
      ),
      ImportIssueCode.notEntry => l10n.importIssueNotEntry,
      ImportIssueCode.invalidEntry => l10n.importIssueInvalidEntry,
    };

/// `512 B`, `256 KB`, `1.4 MB` — a size a user can read at a glance, never a
/// raw byte count in a list.
String cloudBackupFileSize(AppLocalizations l10n, int? bytes) {
  if (bytes == null) return l10n.cloudBackupSizeUnknown;
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    final double kb = bytes / 1024;
    return '${kb < 10 ? kb.toStringAsFixed(1) : kb.round()} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// A stored UTC timestamp as the device-local `2026-11-26 11:28`.
///
/// Presentation only: the ISO string keeps living in the success record, the
/// object name and the exported dataset exactly as written. A missing or
/// unreadable value says so instead of rendering `1970-01-01 08:00`.
String cloudBackupTime(AppLocalizations l10n, Object? raw) {
  final DateTime? parsed = raw is String ? DateTime.tryParse(raw) : null;
  return parsed == null ? l10n.cloudBackupUnknownTime : formatDateTime(parsed);
}

/// How a configured target is named in a selector or a list row.
///
/// S3 is identified by its bucket, WebDAV by its host: the full endpoint would
/// take three lines of a menu row and tell the user nothing extra.
String cloudBackupTargetLabel(CloudBackupConfig config) {
  if (config.providerId == 's3') return 'S3 · ${config.bucket}';
  final String host = Uri.tryParse(config.endpoint)?.host ?? '';
  return 'WebDAV · ${host.isEmpty ? config.endpoint : host}';
}
