import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_models.dart';
import '../../core/repositories/wordbook_repository.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/l10n.dart';
import '../../services/import_service.dart';
import '../../shared/widgets/classic_select.dart';
import '../../shared/widgets/common.dart';
import '../study/practice_page.dart';
import '../study/sprint_page.dart';
import '../study/study_page.dart';
import '../word_management/import_page.dart';

/// "Today" screen: everything needed to start learning, all from the database.
///
/// Every number here is derived from real rows — the previous version could
/// announce "30 new words left" on an empty library because it only subtracted
/// finished cards from the goal.
///
/// Deliberate restraint: one primary action (start), one secondary action
/// (review only) and one flat list of special drills. The dashboard used to
/// show seven buttons of four different weights plus shortcut tiles that only
/// duplicated the navigation bar; both are gone.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TodayProgress> progress = ref.watch(todayProgressProvider);
    final AsyncValue<List<WordBookSummary>> books = ref.watch(
      bookSummariesProvider,
    );
    final AsyncValue<StudySettingsRow> settings = ref.watch(settingsProvider);
    final resume = ref.watch(pausedSessionProvider).value;
    final sprint = ref.watch(sprintPlanProvider).value;
    final canResume =
        resume != null &&
        (resume.bookId == null ||
            (books.value?.any((b) => b.book.id == resume.bookId) ?? false));
    final TodayProgress? today = progress.value;
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayProgressProvider);
        ref.invalidate(bookSummariesProvider);
        await ref.read(todayProgressProvider.future);
      },
      child: ContentColumn(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            if (progress.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ErrorBanner(
                  message: l10n.errorLoadFailed,
                  onRetry: () => ref.invalidate(todayProgressProvider),
                ),
              ),
            _BookSelector(
              books: books.value ?? const <WordBookSummary>[],
              currentBookId: settings.value?.currentWordBookId,
              onChanged: (String? id) async {
                await ref
                    .read(settingsRepositoryProvider)
                    .save(currentWordBookId: Value<String?>(id));
                ref.invalidate(todayProgressProvider);
              },
            ),
            SettingsTile(
              leading: const Icon(Icons.flag_outlined),
              title: l10n.specialSprint,
              subtitle: sprint?.enabled == true
                  ? l10n.sprintTileSubtitleOn(
                      sprint!.examDate ?? '',
                      sprint.roundSize,
                    )
                  : l10n.sprintTileSubtitleOff,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const SprintPage()),
              ),
            ),
            if (canResume)
              SettingsTile(
                leading: const Icon(Icons.play_circle_outline),
                title: l10n.continueStudying,
                subtitle: l10n.resumeProgress(resume.position, resume.total),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => StudyPage(
                      reviewOnly: resume.mode == StudyMode.reviewOnly,
                      special: resume.special,
                      bookIdOverride: resume.bookId,
                      useGlobalScope: resume.bookId == null,
                    ),
                  ),
                ),
              ),
            if (today == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (today.totalWords == 0) ...<Widget>[
              SectionHeader(
                title: l10n.todayTasks,
                trailing: Text(
                  today.scopedToBook
                      ? l10n.scopeCurrentList
                      : l10n.scopeAllLists,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const _FirstRunPanel(),
            ] else ...<Widget>[
              SectionHeader(
                title: l10n.todayTasks,
                trailing: Text(
                  today.scopedToBook
                      ? l10n.scopeCurrentList
                      : l10n.scopeAllLists,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              _TodayPanel(progress: today),
              if (today.backlog > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    l10n.backlogNote(today.backlog),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              SectionHeader(title: l10n.sectionStartStudy),
              _StartActions(progress: today),
              SectionHeader(title: l10n.sectionSpecialReview),
              _SpecialReviewGroup(progress: today),
              SectionHeader(title: l10n.sectionPractice),
              const _PracticeActions(),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _openStudy(
  BuildContext context,
  WidgetRef ref, {
  SpecialReview special = SpecialReview.none,
  bool reviewOnly = false,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          StudyPage(reviewOnly: reviewOnly, special: special),
    ),
  );
  ref.invalidate(todayProgressProvider);
  ref.invalidate(statisticsProvider);
  ref.invalidate(bookSummariesProvider);
}

/// Current-book selector. The trailing "词书" text button was removed: the
/// navigation bar already has a 词书 destination, and a second entry next to the
/// selector only added a way to leave the page by accident.
class _BookSelector extends StatelessWidget {
  const _BookSelector({
    required this.books,
    required this.currentBookId,
    required this.onChanged,
  });

  final List<WordBookSummary> books;
  final String? currentBookId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool bookMissing =
        currentBookId != null &&
        !books.any((WordBookSummary b) => b.book.id == currentBookId);
    final String selectedId = bookMissing ? '' : (currentBookId ?? '');
    return Material(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.menu_book,
              size: AppDimens.iconSizeSmall,
              color: theme.colorScheme.primary,
            ),
            AppSpacing.w8,
            Text(context.l10n.studyWordList, style: theme.textTheme.bodySmall),
            AppSpacing.w12,
            Flexible(
              child: ClassicSelectChip<String>(
                label: context.l10n.scopeAllLists,
                value: selectedId,
                options: <ClassicOption<String>>[
                  ClassicOption<String>(
                    value: '',
                    label: context.l10n.scopeAllLists,
                  ),
                  for (final WordBookSummary summary in books)
                    ClassicOption<String>(
                      value: summary.book.id,
                      label: context.l10n.wordListOptionLabel(
                        summary.book.name,
                        summary.wordCount,
                      ),
                    ),
                ],
                onChanged: (String id) => onChanged(id.isEmpty ? null : id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.progress});

  final TodayProgress progress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ProgressRow(
              label: context.l10n.newWords,
              done: progress.newDone,
              total: progress.newGoal,
              color: theme.colorScheme.primary,
              hint: progress.unlearnedTotal == 0
                  ? context.l10n.noNewWordsInScope
                  : context.l10n.newWordsHintRemaining(
                      progress.newRemainingAllowance,
                      progress.unlearnedTotal,
                    ),
            ),
            AppSpacing.h12,
            ProgressRow(
              label: context.l10n.review,
              done: progress.reviewDone,
              total: progress.reviewGoal,
              color: AppColors.hazy,
              hint: progress.dueTotal == 0
                  ? context.l10n.noDueWords
                  : context.l10n.reviewHintRemaining(
                      progress.dueTotal,
                      progress.reviewRemainingAllowance,
                    ),
            ),
            const Divider(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: StatBlock(
                    value: '${progress.newAvailableToday}',
                    label: context.l10n.newWordsAvailable,
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    value: '${progress.reviewAvailableToday}',
                    label: context.l10n.reviewsAvailable,
                    color: progress.reviewAvailableToday > 0
                        ? AppColors.hazy
                        : null,
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    value: '${progress.backlog}',
                    label: context.l10n.overdueReviews,
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    value: '${progress.hardWords}',
                    label: context.l10n.difficultWords,
                    color: progress.hardWords > 0 ? AppColors.unknown : null,
                  ),
                ),
              ],
            ),
            AppSpacing.h8,
            Text(
              context.l10n.learnedOfTotal(
                progress.learnedWords,
                progress.totalWords,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// One primary (filled) and one secondary (outlined) action. The counts moved
/// into the progress panel above, so the primary label never wraps.
class _StartActions extends ConsumerWidget {
  const _StartActions({required this.progress});

  final TodayProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    if (!progress.hasWork) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.done_all,
              size: AppDimens.iconSizeSmall,
              color: AppColors.known,
            ),
            AppSpacing.w8,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.todayDone,
                    style: theme.textTheme.bodyMedium,
                  ),
                  AppSpacing.h4,
                  Text(
                    context.l10n.todayDoneHint,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final Widget primary = Builder(
      builder: (BuildContext context) => ElevatedButton.icon(
        onPressed: progress.canStartNew || progress.canStartReview
            ? () => _openStudy(context, ref)
            : null,
        icon: const Icon(Icons.play_arrow),
        label: Text(context.l10n.startStudying),
      ),
    );
    final Widget secondary = Builder(
      builder: (BuildContext context) => OutlinedButton.icon(
        onPressed: progress.canStartReview
            ? () => _openStudy(context, ref, reviewOnly: true)
            : null,
        icon: const Icon(Icons.replay),
        label: Text(context.l10n.reviewOnly),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[primary, AppSpacing.h8, secondary],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(flex: 3, child: primary),
              AppSpacing.w8,
              Expanded(flex: 2, child: secondary),
            ],
          );
        },
      ),
    );
  }
}

/// Focused drills are list rows, not buttons: they are secondary entry points
/// and must not compete with "开始学习" for attention.
class _SpecialReviewGroup extends ConsumerWidget {
  const _SpecialReviewGroup({required this.progress});

  final TodayProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
      children: <Widget>[
        SettingsTile(
          leading: const Icon(Icons.local_fire_department_outlined),
          title: context.l10n.specialHard,
          subtitle: progress.hardWords > 0
              ? context.l10n.hardWordsSubtitle(progress.hardWords)
              : context.l10n.noHardWordsYet,
          trailing: const Icon(Icons.chevron_right),
          onTap: progress.hardWords > 0
              ? () => _openStudy(context, ref, special: SpecialReview.hard)
              : null,
        ),
        SettingsTile(
          leading: const Icon(Icons.error_outline),
          title: context.l10n.specialMistakes,
          subtitle: context.l10n.mistakesSubtitle,
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              _openStudy(context, ref, special: SpecialReview.recentMistakes),
        ),
      ],
    );
  }
}

/// Practice entry points. Available even when the daily target is finished:
/// drills are a different activity from the scheduled queue, they consume no
/// daily allowance and they never move a word's long-term interval.
class _PracticeActions extends ConsumerWidget {
  const _PracticeActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String? bookId = ref.watch(activeBookIdProvider);
    return SettingsGroup(
      children: <Widget>[
        for (final PracticeKind kind in PracticeKind.values)
          SettingsTile(
            leading: Icon(switch (kind) {
              PracticeKind.spelling => Icons.keyboard_outlined,
              PracticeKind.dictation => Icons.hearing_outlined,
              PracticeKind.choice => Icons.checklist_outlined,
              PracticeKind.cloze => Icons.short_text_outlined,
            }),
            title: kind.label(context.l10n),
            subtitle: kind == PracticeKind.cloze
                ? '${kind.description(context.l10n)} ${context.l10n.clozeUsesOwnSentence}'
                : kind.description(context.l10n),
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      PracticePage(kind: kind, bookId: bookId),
                ),
              );
              ref.invalidate(statisticsProvider);
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            context.l10n.practiceNote,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _FirstRunPanel extends ConsumerWidget {
  const _FirstRunPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(context.l10n.noWordsYet, style: theme.textTheme.titleLarge),
          AppSpacing.h8,
          Text(context.l10n.firstRunBody, style: theme.textTheme.bodyMedium),
          AppSpacing.h16,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const ImportPage(),
                    ),
                  );
                  ref.invalidate(todayProgressProvider);
                  ref.invalidate(bookSummariesProvider);
                },
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(context.l10n.importWordList),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final SampleWordListResult result =
                        await loadSampleWordbook(ref);
                    if (context.mounted) {
                      showMessage(
                        context,
                        context.l10n.sampleLoaded(
                          result.name,
                          result.wordCount,
                        ),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      showMessage(
                        context,
                        context.l10n.sampleAddFailed,
                        error: true,
                      );
                    }
                  }
                  ref.invalidate(todayProgressProvider);
                  ref.invalidate(bookSummariesProvider);
                },
                icon: const Icon(Icons.auto_stories_outlined),
                label: Text(context.l10n.addSampleList),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Outcome of adding the bundled demo word list.
class SampleWordListResult {
  const SampleWordListResult({required this.name, required this.wordCount});

  final String name;
  final int wordCount;
}

/// Loads the bundled demo word list (30 CET-6 words, from ECDICT, MIT) so a
/// brand-new install can try the learning loop immediately.
///
/// Returns data, not a sentence: the caller localises the confirmation, so the
/// service layer stays language-independent.
Future<SampleWordListResult> loadSampleWordbook(WidgetRef ref) async {
  final ImportService service = ref.read(importServiceProvider);
  final String content = await rootBundle.loadString(
    'assets/wordbooks/sample_cet6.json',
  );
  final ImportPreview preview = service.parseContent(
    content,
    format: 'json',
    name: 'sample_cet6.json',
  );
  if (preview.entries.isEmpty) {
    throw StateError('sample word list is empty');
  }
  final WordBook book = await ref
      .read(wordBookRepositoryProvider)
      .ensureBook(
        name: preview.detectedBookName,
        description: 'Sample word list: 30 CET-6 words (ECDICT, MIT)',
        sourceType: 'sample',
        now: DateTime.now(),
      );
  final ImportOutcome outcome = await service.commit(
    preview: preview,
    bookId: book.id,
    now: DateTime.now(),
  );
  await ref
      .read(settingsRepositoryProvider)
      .save(currentWordBookId: Value<String?>(book.id));
  return SampleWordListResult(name: book.name, wordCount: outcome.created);
}
