import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/error_labels.dart';
import '../../l10n/l10n.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../shared/widgets/common.dart';
import '../../services/practice_session.dart';
import '../../services/screen_awake.dart';
import '../../services/tts_service.dart';

/// Practice drills: spelling, dictation, multiple choice and cloze.
///
/// A drill is deliberately separate from the review session:
///  * it never consumes the daily new/review allowance,
///  * it never moves the long-term interval (see `ReviewEventMode.isPractice`),
///  * but every answer is still a real, undoable, syncable event.
///
/// The page renders whatever [PracticeSession.phase] says and owns nothing that
/// the session also owns: the question on screen during feedback is
/// `session.current`, never a stale copy.
class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({
    super.key,
    required this.kind,
    this.bookId,
    this.limit = PracticeSession.defaultLimit,
    this.resume = true,
  });

  final PracticeKind kind;
  final String? bookId;
  final int limit;

  /// Whether a persisted attempt of the same drill may be resumed.
  final bool resume;

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage>
    with WidgetsBindingObserver {
  late final PracticeSession _session;
  // Resolved eagerly: `ref` must not be touched in dispose().
  late final TtsService _tts;
  late final ScreenAwakeService _screen;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'practice-answer');

  /// Identity of the question the widgets are currently built for. Only used to
  /// decide when to reset the text field and when to pronounce a dictation —
  /// never to decide which question is "current" (the session owns that).
  String? _shownQuestionId;
  PracticePhase? _shownPhase;

  /// Drops pronunciation results that belong to a question already left.
  int _speechGeneration = 0;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts = ref.read(ttsServiceProvider);
    _screen = ref.read(screenAwakeProvider);
    // Rebuild desktop bindings when the typed field gains or loses focus so
    // digits / Space are never stolen from an active TextField.
    _focus.addListener(_onAnswerFocusChanged);
    _session = PracticeSession(
      ref.read(studyRepositoryProvider),
      ref.read(settingsRepositoryProvider),
      ref.read(clockProvider),
    )..addListener(_onChanged);
    _start();
    _applyScreenAwake();
  }

  void _onAnswerFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _applyScreenAwake() async {
    final bool wanted = await ref.read(keepScreenOnProvider.future);
    if (!wanted || !mounted) return;
    await _screen.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speechGeneration++;
    _session.removeListener(_onChanged);
    _session.dispose();
    _controller.dispose();
    _focus.removeListener(_onAnswerFocusChanged);
    _focus.dispose();
    // Stop any pronunciation started for the previous card.
    _tts.stop();
    _screen.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background audio must not outlive the drill: Android/iOS keep the audio
    // session alive otherwise, and the user comes back to a voice reading a
    // word that is no longer on screen.
    if (state != AppLifecycleState.resumed) {
      _speechGeneration++;
      _tts.stop();
      // The OS drops the keep-awake flag in the background; re-apply on return.
      _screen.disable();
    } else {
      _screen.refresh();
    }
  }

  Future<void> _start() async {
    await _session.load(
      kind: widget.kind,
      bookId: widget.bookId,
      limit: widget.limit,
      resume: widget.resume,
    );
    if (!mounted) return;
    ref.invalidate(statisticsProvider);
    _onChanged();
  }

  void _onChanged() {
    if (!mounted) return;
    final PracticeQuestion? question = _session.current;
    final String? id = question == null
        ? null
        : '${question.word.id}:${question.contentSignature}';
    final PracticePhase phase = _session.phase;
    final bool questionChanged = id != _shownQuestionId;
    final bool enteredQuestion =
        questionChanged ||
        (phase == PracticePhase.question &&
            _shownPhase != PracticePhase.question);
    if (questionChanged) {
      _controller.clear();
      _showHint = false;
      // A new card always invalidates the previous pronunciation request.
      _speechGeneration++;
    }
    _shownQuestionId = id;
    _shownPhase = phase;
    setState(() {});
    if (enteredQuestion &&
        question != null &&
        phase == PracticePhase.question &&
        question.kind == PracticeKind.dictation) {
      _speak(question.answer, announceFailure: true);
    }
    if (enteredQuestion && phase == PracticePhase.question) {
      // Focus is requested after the frame so the field exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _session.phase == PracticePhase.question &&
            question != null &&
            question.kind.isTyped) {
          _focus.requestFocus();
        }
      });
    }
  }

  Future<void> _speak(String text, {bool announceFailure = false}) async {
    // Anything older than this request must not report back to the UI.
    final int generation = ++_speechGeneration;
    final StudySettingsRow? settings = ref.read(settingsProvider).value;
    final bool ok = await _tts.speak(
      text,
      voiceName: (settings?.ttsVoice.isEmpty ?? true)
          ? null
          : settings!.ttsVoice,
      locale: settings?.ttsLocale ?? 'en-US',
      rate: settings?.ttsRate ?? 50,
    );
    if (generation != _speechGeneration) return;
    if (!mounted) return;
    if (!ok) {
      // The drill stays usable without audio: show the Chinese hint and say so
      // in Chinese. Never a fake "played" state.
      setState(() => _showHint = true);
      if (announceFailure) {
        showMessage(context, context.l10n.practiceVoiceHintUsed, error: true);
      }
    }
  }

  Future<void> _submitTyped() async {
    if (_session.phase != PracticePhase.question || _session.current == null) {
      return;
    }
    final PracticeOutcome? outcome = await _session.submitTyped(
      _controller.text,
    );
    if (!mounted) return;
    if (outcome == null) {
      if (_session.error != null) {
        showMessage(
          context,
          describeAppError(context.l10n, _session.error!),
          error: true,
        );
      }
      return;
    }
    FocusScope.of(context).unfocus();
    ref.invalidate(statisticsProvider);
    ref.invalidate(todayProgressProvider);
  }

  Future<void> _submitChoice(int index) async {
    if (_session.phase != PracticePhase.question) return;
    final PracticeOutcome? outcome = await _session.submitChoice(index);
    if (!mounted || outcome == null) return;
    ref.invalidate(statisticsProvider);
    ref.invalidate(todayProgressProvider);
  }

  void _next() {
    _session.advance();
  }

  Future<void> _undo() async {
    final bool ok = await _session.undo();
    if (!mounted) return;
    if (!ok && _session.error != null) {
      showMessage(
        context,
        describeAppError(context.l10n, _session.error!),
        error: true,
      );
    }
  }

  void _skip() {
    if (!_session.skip() && _session.error != null) {
      showMessage(
        context,
        describeAppError(context.l10n, _session.error!),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasQuestion = _session.current != null;
    final bool desktop = isDesktopPlatform(context);
    final Widget scaffold = Scaffold(
      appBar: ClassicAppBar(
        title: Text(widget.kind.label(context.l10n)),
        actions: <Widget>[
          IconButton(
            tooltip: context.l10n.undoLastQuestion,
            onPressed: _session.canUndo ? _undo : null,
            icon: const Icon(Icons.undo),
          ),
          if (_session.phase == PracticePhase.question && hasQuestion)
            IconButton(
              tooltip: context.l10n.skip,
              onPressed: _skip,
              icon: const Icon(Icons.skip_next),
            ),
          if (!_session.isLoading && _session.total > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_session.questionNumber}/${_session.total}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (_session.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ErrorBanner(
                  message: describeAppError(context.l10n, _session.error!),
                  onRetry: _session.isFinished || _session.isEmpty
                      ? () => _start()
                      : null,
                ),
              ),
            Expanded(child: _buildBody(theme)),
            if (hasQuestion && !_session.isFinished)
              _AnswerArea(
                kind: widget.kind,
                controller: _controller,
                focusNode: _focus,
                busy: _session.isBusy,
                answered: _session.isFeedback,
                isLast: _session.isLastQuestion,
                onSpeak: widget.kind == PracticeKind.dictation
                    ? () => _speak(_session.current?.answer ?? '')
                    : null,
                onToggleHint: () => setState(() => _showHint = !_showHint),
                showHint: _showHint,
                onSubmit: _submitTyped,
                onNext: _next,
              ),
          ],
        ),
      ),
    );
    if (!desktop) return scaffold;
    // Desktop only: 1–4 pick a choice before an answer; Space advances after.
    // Bindings are empty while the typed field owns focus so digits and Space
    // stay with the input. No keycap labels are drawn.
    return CallbackShortcuts(
      bindings: _desktopBindings(),
      child: Focus(autofocus: true, child: scaffold),
    );
  }

  Map<ShortcutActivator, VoidCallback> _desktopBindings() {
    if (_focus.hasFocus) return const <ShortcutActivator, VoidCallback>{};
    if (_session.isFeedback) {
      return <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): _next,
      };
    }
    if (_session.phase != PracticePhase.question ||
        _session.isBusy ||
        widget.kind != PracticeKind.choice) {
      return const <ShortcutActivator, VoidCallback>{};
    }
    final PracticeQuestion? question = _session.current;
    if (question == null) return const <ShortcutActivator, VoidCallback>{};
    final List<LogicalKeyboardKey> digits = <LogicalKeyboardKey>[
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ];
    final Map<ShortcutActivator, VoidCallback> bindings =
        <ShortcutActivator, VoidCallback>{};
    for (int i = 0; i < digits.length && i < question.options.length; i++) {
      final int index = i;
      bindings[SingleActivator(digits[i])] = () => _submitChoice(index);
    }
    return bindings;
  }

  Widget _buildBody(ThemeData theme) {
    if (_session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_session.isEmpty) {
      return EmptyState(
        icon: Icons.school_outlined,
        title: _session.error == null
            ? context.l10n.nothingToPractice
            : context.l10n.practiceCannotStart,
        message: widget.kind == PracticeKind.cloze
            ? context.l10n.clozeEmptyMessage
            : context.l10n.practiceEmptyMessage,
        action: ElevatedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(context.l10n.back),
        ),
      );
    }
    if (_session.isFinished) {
      return _SummaryView(
        summary: _session.summary(),
        onDone: () => Navigator.of(context).maybePop(),
        onAgain: _restartSession,
      );
    }
    final PracticeQuestion? question = _session.current;
    if (question == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ContentWidth(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _PromptCard(
              question: question,
              showHint: _showHint,
              outcome: _session.outcome,
              onSpeak: () => _speak(question.answer),
              onChoice:
                  _session.phase == PracticePhase.question && !_session.isBusy
                  ? _submitChoice
                  : null,
            ),
            if (_session.outcome != null) ...<Widget>[
              AppSpacing.h16,
              _FeedbackCard(outcome: _session.outcome!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _restartSession() async {
    _shownQuestionId = null;
    _shownPhase = null;
    await _start();
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.question,
    required this.showHint,
    required this.outcome,
    required this.onSpeak,
    required this.onChoice,
  });

  final PracticeQuestion question;
  final bool showHint;
  final PracticeOutcome? outcome;
  final VoidCallback onSpeak;
  final void Function(int index)? onChoice;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (question.kind == PracticeKind.dictation) ...<Widget>[
          Center(
            child: IconButton(
              tooltip: context.l10n.playAgain,
              iconSize: 56,
              onPressed: onSpeak,
              icon: Icon(Icons.volume_up, color: theme.colorScheme.primary),
            ),
          ),
          Center(
            child: Text(
              context.l10n.listenAndType,
              style: theme.textTheme.bodySmall,
            ),
          ),
          AppSpacing.h12,
        ],
        if (question.kind == PracticeKind.cloze)
          SelectableText(
            question.prompt,
            style: theme.classicStyle(theme.textTheme.bodyLarge, height: 1.6),
          )
        else
          SelectableText(
            question.prompt,
            textAlign: TextAlign.center,
            style: theme.classicStyle(
              theme.textTheme.headlineSmall,
              height: 1.4,
            ),
          ),
        if (question.kind == PracticeKind.dictation && showHint) ...<Widget>[
          AppSpacing.h12,
          Text(
            question.word.translation,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
        if (question.kind == PracticeKind.choice) ...<Widget>[
          AppSpacing.h16,
          for (int i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: onChoice == null ? null : () => onChoice!(i),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.fromHeight(
                    theme.isClassicType ? 48 : theme.buttonMinHeight,
                  ),
                  alignment: Alignment.centerLeft,
                  backgroundColor: _optionColor(context, i),
                ),
                child: Text(question.options[i]),
              ),
            ),
        ],
        if (question.kind == PracticeKind.cloze && question.prompt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              context.l10n.hintWithText(question.word.translation),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Color? _optionColor(BuildContext context, int index) {
    final PracticeOutcome? result = outcome;
    if (result == null) return null;
    if (index == question.correctIndex) {
      return AppColors.known.withValues(alpha: 0.14);
    }
    return null;
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.outcome});

  final PracticeOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = outcome.correct ? AppColors.known : AppColors.unknown;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: theme.surfaceRadius,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                outcome.correct
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: color,
                size: AppDimens.iconSizeSmall,
              ),
              AppSpacing.w8,
              Text(
                outcome.correct ? context.l10n.correct : context.l10n.incorrect,
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
          AppSpacing.h8,
          // Just the word itself — never restate a highlighted choice as
          // "correct spelling", never echo the wrong typed string, and never
          // repeat the interval note under every answer.
          SelectableText(outcome.answer, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _AnswerArea extends StatelessWidget {
  const _AnswerArea({
    required this.kind,
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.answered,
    required this.isLast,
    required this.showHint,
    required this.onToggleHint,
    required this.onSubmit,
    required this.onNext,
    this.onSpeak,
  });

  final PracticeKind kind;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final bool answered;
  final bool isLast;
  final bool showHint;
  final VoidCallback onToggleHint;
  final Future<void> Function() onSubmit;
  final VoidCallback onNext;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double controlHeight = theme.isClassicType
        ? 48
        : theme.buttonMinHeight;
    return Material(
      color: theme.cardColor,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: answered
            ? SizedBox(
                height: controlHeight,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNext,
                  // The last question shows its feedback too; the button then
                  // leads to the summary instead of pretending the round is over.
                  child: Text(
                    isLast
                        ? context.l10n.viewResults
                        : context.l10n.nextQuestion,
                  ),
                ),
              )
            : Row(
                children: <Widget>[
                  if (kind.isTyped) ...<Widget>[
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !busy,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        onSubmitted: (_) => onSubmit(),
                        decoration: InputDecoration(
                          hintText: context.l10n.typeTheWord,
                          suffixIcon: onSpeak == null
                              ? null
                              : IconButton(
                                  tooltip: context.l10n.playAgain,
                                  onPressed: onSpeak,
                                  icon: const Icon(Icons.volume_up_outlined),
                                ),
                        ),
                      ),
                    ),
                    AppSpacing.w8,
                    SizedBox(
                      height: controlHeight,
                      child: ElevatedButton(
                        onPressed: busy ? null : onSubmit,
                        child: Text(context.l10n.submit),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        context.l10n.chooseCorrectWord,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (kind == PracticeKind.dictation) ...<Widget>[
                    IconButton(
                      tooltip: showHint
                          ? context.l10n.hideHint
                          : context.l10n.showHint,
                      onPressed: onToggleHint,
                      icon: Icon(
                        showHint
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.summary,
    required this.onDone,
    required this.onAgain,
  });

  final PracticeSummary summary;
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
                Icons.school_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              AppSpacing.h12,
              Text(
                context.l10n.practiceComplete,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              AppSpacing.h24,
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatBlock(
                      value: '${summary.answered}',
                      label: context.l10n.answersCount,
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      value: '${summary.correct}',
                      label: context.l10n.correct,
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      value: '${summary.skipped}',
                      label: context.l10n.skipped,
                    ),
                  ),
                ],
              ),
              AppSpacing.h12,
              Text(
                context.l10n.practiceAccuracy(
                  summary.accuracy == null
                      ? '—'
                      : '${(summary.accuracy! * 100).toStringAsFixed(1)}%',
                  summary.uniqueWords,
                ),
                textAlign: TextAlign.center,
              ),
              if (summary.wrongWords.isNotEmpty) ...<Widget>[
                AppSpacing.h16,
                Text(
                  context.l10n.worthAnotherLook,
                  style: theme.textTheme.titleSmall,
                ),
                AppSpacing.h8,
                SelectableText(summary.wrongWords.join(' · ')),
              ],
              AppSpacing.h12,
              Text(
                context.l10n.practiceStatsNote,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              AppSpacing.h24,
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onAgain,
                      child: Text(context.l10n.continuePracticing),
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
