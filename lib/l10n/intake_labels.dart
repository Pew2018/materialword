import '../services/word_intake_service.dart';
import 'l10n.dart';

/// One line describing what an "add word" call actually did.
///
/// The service returns data ([WordIntakeResult]); the sentence is built here so
/// the same result can be shown in Chinese or English, and so the service never
/// claims more than happened (for example "already in this list" instead of
/// "added").
String describeIntake(AppLocalizations l10n, WordIntakeResult result) {
  final String word = result.word.word;
  return switch (result.kind) {
    IntakeKind.created => l10n.intakeAdded(word),
    IntakeKind.revived =>
      result.linkAdded
          ? l10n.intakeRevivedLinked(word)
          : l10n.intakeRevived(word),
    IntakeKind.updated =>
      result.changedFields.isEmpty
          ? l10n.intakeUnchanged(word)
          : l10n.intakeUpdated(result.changedFields.length, word),
    IntakeKind.unchanged =>
      result.alreadyLinked
          ? l10n.intakeAlreadyInList(word)
          : l10n.intakeExists(word),
    IntakeKind.deletedSkipped => l10n.intakeDeletedSkipped(word),
  };
}
