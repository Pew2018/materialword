import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_models.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/error_labels.dart';
import '../../l10n/l10n.dart';
import '../../services/screen_awake.dart';
import '../../services/study_session.dart';
import '../../services/tts_service.dart';
import '../../shared/widgets/common.dart';
import '../word_management/word_metadata_widgets.dart';
import '../word_management/word_detail_page.dart';

/// Learning / review screen.
///
/// Layout contract:
///  * the word is the visual hero, the Chinese meaning is primary and the
///    English definition is secondary (collapsible);
///  * content scrolls, the answer bar is pinned to the bottom — a long
///    definition can never push the buttons off screen;
///  * answers are only accepted after the meaning is revealed;
///  * desktop shortcuts (Space / 1 / 2 / 3) are disabled while text is being
///    edited or a dialog is open, and are never advertised on phones.
class StudyPage extends ConsumerStatefulWidget {
  const StudyPage({
    super.key,
    this.reviewOnly = false,
    this.special = SpecialReview.none,
    this.bookIdOverride,
    this.useGlobalScope = false,
    this.focusedWordIds,
  });

  final bool reviewOnly;
  final SpecialReview special;

  /// Forces the queue to a specific book (used by the "词书内专项复习" entry);
  /// normal study always follows the book selected in settings.
  final String? bookIdOverride;
  final bool useGlobalScope;
  final List<String>? focusedWordIds;

  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage>
    with WidgetsBindingObserver {
  late final StudySession _session;
  final ScrollController _scroll = ScrollController();
  bool _started = false;
  String? _lastCardId;
  StudySettingsRow? _settings;
  bool _randomOrder = false;
  static const String _randomOrderKey = 'study_random_order';
  late final TtsService _tts;
  late final ScreenAwakeService _screen;
  Future<StudyRoundSummary>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Resolved eagerly: `ref` must not be touched in dispose().
    _tts = ref.read(ttsServiceProvider);
    _screen = ref.read(screenAwakeProvider);
    _session = StudySession(
      ref.read(studyRepositoryProvider),
      ref.read(settingsRepositoryProvider),
      ref.read(clockProvider),
    )..addListener(_onSessionChanged);
    _start();
    _applyScreenAwake();
  }

  /// Only ever keeps the screen on while this page is the visible session and
  /// the user asked for it; a platform that cannot do it says so once and the
  /// session continues unchanged.
  Future<void> _applyScreenAwake() async {
    final bool wanted = await ref.read(keepScreenOnProvider.future);
    if (!wanted || !mounted) return;
    await _screen.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The OS drops the flag while backgrounded, so "still wanted" has to be
      // re-applied rather than assumed.
      unawaited(_screen.refresh());
    } else {
      unawaited(_screen.disable());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _scroll.dispose();
    // Captured in initState: `ref` must not be used while disposing.
    _tts.stop();
    _screen.disable();
    super.dispose();
  }

  void _onSessionChanged() {
    if (_session.isFinished) {
      _summaryFuture ??= _session.summary();
    } else {
      _summaryFuture = null;
    }
    if (_session.isFinished &&
        _session.newAnswered + _session.reviewAnswered > 0) {
      ref.read(autoSyncServiceProvider).requestSessionEnd();
    }
    final StudyCard? card = _session.current;
    final String? id = card == null
        ? null
        : '${card.word.id}:${card.word.hashCode}';
    if (id == _lastCardId) return;
    _lastCardId = id;
    // Keep the header at the same place for every card: no jumpy layout.
    _tts.stop();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (card != null && (_settings?.ttsAutoSpeak ?? false)) {
      _speak(card.word.word);
    }
  }

  Future<void> _speak(String text) async {
    final StudySettingsRow? settings = _settings;
    final bool ok = await _tts.speak(
      text,
      voiceName: (settings?.ttsVoice.isEmpty ?? true)
          ? null
          : settings!.ttsVoice,
      locale: settings?.ttsLocale ?? 'en-US',
      rate: settings?.ttsRate ?? 50,
    );
    if (!ok && mounted) {
      showMessage(context, context.l10n.voiceUnavailable, error: true);
    }
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    final StudySettingsRow settings = await ref
        .read(settingsRepositoryProvider)
        .load();
    _settings = settings;
    final DateTime now = ref.read(clockProvider).now();
    final int newDone = await ref
        .read(studyRepositoryProvider)
        .todayCount(now: now, type: ReviewType.study);
    final int reviewDone = await ref
        .read(studyRepositoryProvider)
        .todayCount(now: now, type: ReviewType.review);
    final int newAllowance = (settings.dailyNewTarget - newDone).clamp(
      0,
      settings.dailyNewTarget,
    );
    final int reviewAllowance = (settings.dailyReviewLimit - reviewDone).clamp(
      0,
      settings.dailyReviewLimit,
    );
    final bool isSpecial = widget.special != SpecialReview.none;
    // Device-local preference (not synced): it only changes the order cards are
    // presented in, never which cards are in the queue.
    _randomOrder =
        await ref.read(databaseProvider).readMeta(_randomOrderKey) == '1';
    await _session.load(
      newLimit: isSpecial ? 0 : newAllowance,
      // A special pass still consumes the review allowance, but we always allow
      // at least a short focused run so the entry point is never a dead end.
      reviewLimit: isSpecial
          ? (reviewAllowance > 0 ? reviewAllowance : 20)
          : reviewAllowance,
      bookId: widget.useGlobalScope
          ? null
          : widget.bookIdOverride ?? settings.currentWordBookId,
      focusedWordIds: widget.focusedWordIds,
      mode: widget.reviewOnly
          ? StudyMode.reviewOnly
          : StudyMode.fromCode(settings.studyMode),
      special: widget.special,
      shuffle: _randomOrder && !isSpecial,
    );
    if (!mounted) return;
    setState(() {});
    _onSessionChanged();
  }

  Future<void> _answer(AnswerResult result) async {
    await _session.submit(result);
    if (!mounted) return;
    ref.invalidate(todayProgressProvider);
    ref.invalidate(statisticsProvider);
  }

  Future<void> _undo() async {
    await _session.undo();
    if (!mounted) return;
    ref.invalidate(todayProgressProvider);
    ref.invalidate(statisticsProvider);
  }

  bool get _shortcutsBlocked {
    if (ModalRoute.of(context)?.isCurrent == false) return true;
    if (Navigator.of(context).canPop() && _hasOpenDialog) return true;
    final BuildContext? focus = FocusManager.instance.primaryFocus?.context;
    return focus?.widget is EditableText;
  }

  bool get _hasOpenDialog {
    // A route pushed on top of the study page means a dialog/page is open.
    return !(ModalRoute.of(context)?.isCurrent ?? true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool desktop = isDesktopPlatform(context);
    final bool compact = MediaQuery.sizeOf(context).width < 600;
    return AnimatedBuilder(
      animation: _session,
      builder: (BuildContext context, Widget? _) {
        return Scaffold(
          appBar: ClassicAppBar(
            title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(
                value: _session.progress,
                minHeight: 3,
                // Works on the light (accent) and dark app bar alike.
                backgroundColor:
                    (theme.appBarTheme.foregroundColor ?? Colors.white)
                        .withValues(alpha: 0.24),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            // A long title plus four icon buttons plus the counter overflowed a
            // 360dp phone. On compact widths the two low-frequency actions collapse into
            // one overflow menu, leaving the AppBar readable.
            actions: <Widget>[
              if (_session.current != null && !_session.isFinished)
                IconButton(
                  tooltip: context.l10n.editWord,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _session.isBusy
                      ? null
                      : () async {
                          final wordId = _session.current!.word.id;
                          await _tts.stop();
                          if (!context.mounted) return;
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => WordDetailPage(
                                wordId: wordId,
                                bookId: widget.bookIdOverride,
                              ),
                            ),
                          );
                          if (mounted) await _session.refreshCurrent();
                        },
                ),
              if (_session.current != null &&
                  !_session.isLoading &&
                  !_session.isFinished)
                FavoriteButton(wordId: _session.current!.word.id),
              if (compact)
                PopupMenuButton<String>(
                  tooltip: context.l10n.moreActions,
                  onSelected: (String value) {
                    if (value == 'skip' && !_session.isBusy) _session.skip();
                    if (value == 'undo' && _session.canUndo) _undo();
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'skip',
                          enabled: _session.current != null && !_session.isBusy,
                          child: Text(context.l10n.skip),
                        ),
                        PopupMenuItem<String>(
                          value: 'undo',
                          enabled: _session.canUndo,
                          child: Text(context.l10n.undoLastAnswer),
                        ),
                      ],
                )
              else ...<Widget>[
                if (_session.current != null && !_session.isLoading)
                  IconButton(
                    tooltip: context.l10n.skip,
                    icon: const Icon(Icons.skip_next),
                    onPressed: _session.isBusy ? null : _session.skip,
                  ),
                IconButton(
                  tooltip: context.l10n.undoLastAnswer,
                  onPressed: _session.canUndo ? _undo : null,
                  icon: const Icon(Icons.undo),
                ),
                if (!_session.isLoading && !_session.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        '${_session.position}/${_session.totalCards}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          body: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): () {
                if (!_shortcutsBlocked && _session.canUndo) _undo();
              },
              const SingleActivator(LogicalKeyboardKey.space): () {
                if (_shortcutsBlocked) return;
                _session.reveal();
              },
              const SingleActivator(LogicalKeyboardKey.enter): () {
                if (_shortcutsBlocked) return;
                if (!_session.isRevealed) _session.reveal();
              },
              const SingleActivator(LogicalKeyboardKey.digit1): () {
                if (_shortcutsBlocked || !_session.isRevealed) return;
                _answer(AnswerResult.unknown);
              },
              const SingleActivator(LogicalKeyboardKey.digit2): () {
                if (_shortcutsBlocked || !_session.isRevealed) return;
                _answer(AnswerResult.hazy);
              },
              const SingleActivator(LogicalKeyboardKey.digit3): () {
                if (_shortcutsBlocked || !_session.isRevealed) return;
                _answer(AnswerResult.known);
              },
            },
            child: Focus(
              autofocus: true,
              child: GestureDetector(
                // Swipe up on the word to reveal the meaning — the same action
                // as the button, never a shortcut around the confirmation.
                onVerticalDragEnd: (DragEndDetails details) {
                  if (_session.isRevealed || _session.isBusy) return;
                  if ((details.primaryVelocity ?? 0) < -250) _session.reveal();
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: <Widget>[
                    if (_session.notice != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          describeAppError(context.l10n, _session.notice!),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Expanded(child: _buildContent(context, desktop)),
                    if (_session.current != null && !_session.isFinished)
                      _AnswerBar(
                        revealed: _session.isRevealed,
                        busy: _session.isBusy,
                        desktop: desktop,
                        onReveal: _session.reveal,
                        onAnswer: _answer,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String get _title {
    final AppLocalizations l10n = context.l10n;
    if (widget.special != SpecialReview.none) return widget.special.label(l10n);
    if (widget.reviewOnly) return l10n.review;
    return l10n.studyTitle;
  }

  Widget _buildContent(BuildContext context, bool desktop) {
    if (_session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_session.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                size: 40,
                color: AppColors.unknown,
              ),
              AppSpacing.h12,
              Text(
                describeAppError(context.l10n, _session.error!),
                textAlign: TextAlign.center,
              ),
              AppSpacing.h16,
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(context.l10n.back),
              ),
            ],
          ),
        ),
      );
    }
    if (_session.isEmpty) {
      final AppLocalizations l10n = context.l10n;
      final bool special = widget.special != SpecialReview.none;
      return EmptyState(
        icon: Icons.done_all,
        title: special ? l10n.nothingDueSpecial : l10n.nothingToStudyToday,
        message: special
            ? l10n.specialEmptyMessage
            : l10n.nothingLeftTodayMessage,
        action: ElevatedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l10n.back),
        ),
      );
    }
    if (_session.isFinished) {
      return FutureBuilder<StudyRoundSummary>(
        future: _summaryFuture ??= _session.summary(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorBanner(
              message: context.l10n.roundSummaryFailed,
              onRetry: () => setState(() {
                _summaryFuture = _session.summary();
              }),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = snapshot.data!;
          return _SummaryView(
            summary: summary,
            backlog: _session.backlog,
            onMistakes: summary.difficultWords.any((w) => w.available)
                ? () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => StudyPage(
                        special: SpecialReview.sessionMistakes,
                        focusedWordIds: summary.difficultWords
                            .where((w) => w.available)
                            .map((w) => w.id)
                            .toList(),
                        bookIdOverride: _session.bookId,
                        useGlobalScope: _session.bookId == null,
                      ),
                    ),
                  )
                : null,
            onDone: () => Navigator.of(context).maybePop(),
            onAgain: () async {
              _started = false;
              await _start();
            },
          );
        },
      );
    }

    final StudyCard card = _session.current!;
    return SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ContentWidth(
        maxWidth: 720,
        child: _WordBody(card: card, revealed: _session.isRevealed),
      ),
    );
  }
}

class _WordBody extends StatelessWidget {
  const _WordBody({required this.card, required this.revealed});

  final StudyCard card;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Word word = card.word;
    final LearningState? state = card.withState.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 8),
        SelectableText(
          word.word,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 38,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (word.phonetic.isNotEmpty)
              Flexible(
                child: Text(
                  '/${word.phonetic}/',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            IconButton(
              tooltip: context.l10n.speak,
              icon: const Icon(Icons.volume_up_outlined),
              iconSize: AppDimens.iconSizeSmall,
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final container = ProviderScope.containerOf(context);
                final tts = container.read(ttsServiceProvider);
                final settings = container.read(settingsProvider).value;
                final bool ok = await tts.speak(
                  word.word,
                  voiceName: (settings?.ttsVoice.isEmpty ?? true)
                      ? null
                      : settings!.ttsVoice,
                  locale: settings?.ttsLocale ?? 'en-US',
                  rate: settings?.ttsRate ?? 50,
                );
                if (!ok && context.mounted) {
                  showMessage(
                    context,
                    context.l10n.voiceUnavailable,
                    error: true,
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: <Widget>[
            if (card.repeatCount > 0)
              TagChip(
                label: context.l10n.repeatPractice,
                color: AppColors.hazy,
                dense: true,
              ),
            if (card.type == ReviewType.study)
              TagChip(label: context.l10n.newWordTag, dense: true)
            else
              TagChip(
                label: context.l10n.reviewWithStage(
                  StudyStage.fromCode(state?.stage ?? 0).label(context.l10n),
                ),
                color: AppColors.hazy,
                dense: true,
              ),
            if (word.examTags.isNotEmpty)
              TagChip(
                label: word.examTags.split(' ').take(2).join(' ').toUpperCase(),
                dense: true,
              ),
            if ((state?.wrongCount ?? 0) > 0)
              TagChip(
                label: context.l10n.wrongCountChip(state!.wrongCount),
                color: AppColors.unknown,
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (!revealed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.visibility_outlined,
                  size: 28,
                  color: theme.disabledColor,
                ),
                AppSpacing.h8,
                Text(
                  context.l10n.recallMeaning,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          )
        else ...<Widget>[
          const Divider(height: 24),
          if (word.partOfSpeech.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                word.partOfSpeech,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          SelectableText(
            word.translation.isEmpty
                ? context.l10n.noChineseMeaning
                : word.translation,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 17,
              height: 1.6,
            ),
          ),
          if (word.definition.isNotEmpty) ...<Widget>[
            AppSpacing.h12,
            _DisclosureSection(
              title: context.l10n.englishDefinition,
              expanded: false,
              child: Text(
                word.definition,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ),
          ],
          if (word.example.isNotEmpty) ...<Widget>[
            AppSpacing.h12,
            _LabeledBlock(
              label: context.l10n.exampleSentence,
              child: word.example,
              italic: true,
            ),
          ],
          if (word.phrase.isNotEmpty) ...<Widget>[
            AppSpacing.h12,
            _LabeledBlock(label: context.l10n.phrases, child: word.phrase),
          ],
          if (word.note.isNotEmpty) ...<Widget>[
            AppSpacing.h12,
            _LabeledBlock(label: context.l10n.notes, child: word.note),
          ],
          if (state != null) ...<Widget>[
            AppSpacing.h16,
            Text(
              context.l10n.studyHistoryShort(
                state.correctCount,
                state.hazyCount,
                state.wrongCount,
                state.intervalDays,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Collapsible secondary content (the English definition).
class _DisclosureSection extends StatefulWidget {
  const _DisclosureSection({
    required this.title,
    required this.child,
    this.expanded = false,
  });

  final String title;
  final Widget child;
  final bool expanded;

  @override
  State<_DisclosureSection> createState() => _DisclosureSectionState();
}

class _DisclosureSectionState extends State<_DisclosureSection> {
  late bool _open = widget.expanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: AppDimens.iconSizeSmall,
                  color: theme.colorScheme.primary,
                ),
                AppSpacing.w4,
                Text(
                  widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: widget.child,
          ),
      ],
    );
  }
}

class _LabeledBlock extends StatelessWidget {
  const _LabeledBlock({
    required this.label,
    required this.child,
    this.italic = false,
  });

  final String label;
  final String child;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: TagChip(label: label, dense: true),
        ),
        AppSpacing.w8,
        Expanded(
          child: SelectableText(
            child,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pinned bottom action area.
///
/// A plain surface with a single hairline divider — not a floating card with a
/// second button inside it. The reveal button fills the action strip (no Space
/// keycap beside it); Space / Enter still reveal via shortcuts. Capped at a
/// readable width on desktop instead of stretching across the whole window.
class _AnswerBar extends StatelessWidget {
  const _AnswerBar({
    required this.revealed,
    required this.busy,
    required this.desktop,
    required this.onReveal,
    required this.onAnswer,
  });

  final bool revealed;
  final bool busy;
  final bool desktop;
  final VoidCallback onReveal;
  final Future<void> Function(AnswerResult result) onAnswer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: revealed ? AppDimens.actionBarMaxWidth : 420,
                  ),
                  child: revealed
                      ? Row(
                          children: <Widget>[
                            _AnswerButton(
                              label: AnswerResult.unknown.label(context.l10n),
                              color: AppColors.unknown,
                              shortcut: desktop ? '1' : null,
                              onPressed: busy
                                  ? null
                                  : () => onAnswer(AnswerResult.unknown),
                            ),
                            AppSpacing.w8,
                            _AnswerButton(
                              label: AnswerResult.hazy.label(context.l10n),
                              color: AppColors.hazy,
                              shortcut: desktop ? '2' : null,
                              onPressed: busy
                                  ? null
                                  : () => onAnswer(AnswerResult.hazy),
                            ),
                            AppSpacing.w8,
                            _AnswerButton(
                              label: AnswerResult.known.label(context.l10n),
                              color: AppColors.known,
                              shortcut: desktop ? '3' : null,
                              onPressed: busy
                                  ? null
                                  : () => onAnswer(AnswerResult.known),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: onReveal,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(40),
                            ),
                            child: Text(context.l10n.showMeaning),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.shortcut,
  });

  final String label;
  final Color color;
  final String? shortcut;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 1,
            padding: EdgeInsets.zero,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.buttonRadius),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (shortcut != null)
                Text(
                  shortcut!,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.summary,
    required this.onMistakes,
    required this.backlog,
    required this.onDone,
    required this.onAgain,
  });

  final StudyRoundSummary summary;
  final VoidCallback? onMistakes;
  final int backlog;
  final VoidCallback onDone;
  final Future<void> Function() onAgain;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ContentWidth(
          maxWidth: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                Icons.check_circle_outline,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              AppSpacing.h12,
              Text(
                context.l10n.roundComplete,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              AppSpacing.h24,
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatBlock(
                      value: '${summary.newWords}',
                      label: context.l10n.newWords,
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      value: '${summary.reviewWords}',
                      label: context.l10n.review,
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      value: '${summary.repeatAttempts}',
                      label: context.l10n.repeatPractice,
                    ),
                  ),
                ],
              ),
              AppSpacing.h16,
              Text(
                context.l10n.wordsAndAnswers(
                  summary.uniqueWords,
                  summary.attempts,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.h12,
              Row(
                children: [
                  Expanded(
                    child: StatBlock(
                      value: '${summary.known}',
                      label: AnswerResult.known.label(context.l10n),
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      value: '${summary.hazy}',
                      label: AnswerResult.hazy.label(context.l10n),
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      value: '${summary.unknown}',
                      label: AnswerResult.unknown.label(context.l10n),
                    ),
                  ),
                ],
              ),
              AppSpacing.h12,
              Text(
                context.l10n.accuracyValue(
                  summary.accuracy == null
                      ? '—'
                      : '${(summary.accuracy! * 100).toStringAsFixed(1)}%',
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                context.l10n.timeSpent(
                  summary.elapsed.inMinutes,
                  summary.elapsed.inSeconds % 60,
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (summary.difficultWords.isNotEmpty) ...[
                AppSpacing.h16,
                Text(
                  context.l10n.roundDifficultWords,
                  style: theme.textTheme.titleSmall,
                ),
                AppSpacing.h8,
                SelectableText(
                  summary.difficultWords
                      .map(
                        (w) =>
                            '${w.word}${w.available ? '' : context.l10n.deletedWordSuffix}',
                      )
                      .join(' · '),
                ),
                Text(
                  context.l10n.roundDifficultNote,
                  style: theme.textTheme.bodySmall,
                ),
                AppSpacing.h12,
                OutlinedButton.icon(
                  onPressed: onMistakes,
                  icon: const Icon(Icons.replay),
                  label: Text(context.l10n.specialSessionMistakes),
                ),
              ],
              if (backlog > 0) ...<Widget>[
                AppSpacing.h16,
                Text(
                  context.l10n.backlogCarried(backlog),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              AppSpacing.h24,
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onAgain,
                      child: Text(context.l10n.continueStudying),
                    ),
                  ),
                  AppSpacing.w8,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onDone,
                      child: Text(context.l10n.commonDone),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
