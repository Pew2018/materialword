import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../shared/widgets/common.dart';
import '../../services/practice_session.dart';
import '../../services/tts_service.dart';

/// Practice drills: spelling, dictation, multiple choice and cloze.
///
/// A drill is deliberately separate from the review session:
///  * it never consumes the daily new/review allowance,
///  * it never moves the long-term interval (see `ReviewEventMode.isPractice`),
///  * but every answer is still a real, undoable, syncable event.
class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({
    super.key,
    required this.kind,
    this.bookId,
    this.limit = PracticeSession.defaultLimit,
  });

  final PracticeKind kind;
  final String? bookId;
  final int limit;

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  late final PracticeSession _session;
  // Resolved eagerly: `ref` must not be touched in dispose().
  late final TtsService _tts;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode(debugLabel: 'practice-answer');
  String? _lastQuestionId;
  PracticeOutcome? _outcome;
  PracticeQuestion? _answeredQuestion;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsServiceProvider);
    _session = PracticeSession(
      ref.read(studyRepositoryProvider),
      ref.read(settingsRepositoryProvider),
      ref.read(clockProvider),
    )..addListener(_onChanged);
    _start();
  }

  @override
  void dispose() {
    _session.removeListener(_onChanged);
    _session.dispose();
    _controller.dispose();
    _focus.dispose();
    // Stop any pronunciation started for the previous card.
    _tts.stop();
    super.dispose();
  }

  Future<void> _start() async {
    await _session.load(
      kind: widget.kind,
      bookId: widget.bookId,
      limit: widget.limit,
    );
    if (!mounted) return;
    ref.invalidate(statisticsProvider);
    _onChanged();
  }

  void _onChanged() {
    if (!mounted) return;
    final PracticeQuestion? question = _session.current;
    if (question == null) {
      setState(() {});
      return;
    }
    final String id = '${question.word.id}:${_session.position}';
    if (id == _lastQuestionId) {
      setState(() {});
      return;
    }
    _lastQuestionId = id;
    _controller.clear();
    _showHint = false;
    setState(() {});
    if (question.kind == PracticeKind.dictation) {
      _speak(question.answer, announceFailure: true);
    }
    // Focus is requested after the frame so the field exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _session.current != null && question.kind.isTyped) {
        _focus.requestFocus();
      }
    });
  }

  Future<void> _speak(String text, {bool announceFailure = false}) async {
    final StudySettingsRow? settings = ref.read(settingsProvider).value;
    final bool ok = await _tts.speak(
      text,
      voiceName: (settings?.ttsVoice.isEmpty ?? true)
          ? null
          : settings!.ttsVoice,
      locale: settings?.ttsLocale ?? 'en-US',
      rate: settings?.ttsRate ?? 50,
    );
    if (!ok && mounted && announceFailure) {
      setState(() => _showHint = true);
      showMessage(context, '系统语音不可用，已显示中文提示；可继续用拼写或选择题练习', error: true);
    }
  }

  Future<void> _submitTyped() async {
    if (_session.isBusy || _session.current == null) return;
    final PracticeQuestion question = _session.current!;
    final PracticeOutcome? outcome = await _session.submitTyped(
      _controller.text,
    );
    if (!mounted) return;
    if (outcome == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _outcome = outcome;
      _answeredQuestion = question;
    });
    ref.invalidate(statisticsProvider);
    ref.invalidate(todayProgressProvider);
  }

  Future<void> _submitChoice(int index) async {
    final PracticeQuestion? question = _session.current;
    if (question == null || _session.isBusy) return;
    final PracticeOutcome? outcome = await _session.submitChoice(index);
    if (!mounted || outcome == null) return;
    setState(() {
      _outcome = outcome;
      _answeredQuestion = question;
    });
    ref.invalidate(statisticsProvider);
    ref.invalidate(todayProgressProvider);
  }

  void _next() {
    setState(() {
      _outcome = null;
      _answeredQuestion = null;
      _showHint = false;
    });
    _controller.clear();
    _onChanged();
  }

  Future<void> _undo() async {
    final bool ok = await _session.undo();
    if (!mounted) return;
    if (ok) {
      setState(() {
        _outcome = null;
        _answeredQuestion = null;
      });
      _lastQuestionId = null;
      _onChanged();
    } else if (_session.error != null) {
      showMessage(context, _session.error!, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind.label),
        actions: <Widget>[
          IconButton(
            tooltip: '撤销上一题',
            onPressed: _session.canUndo ? _undo : null,
            icon: const Icon(Icons.undo),
          ),
          if (!_session.isLoading && !_session.isEmpty && !_session.isFinished)
            IconButton(
              tooltip: '跳过（不记录作答）',
              onPressed: _session.isBusy
                  ? null
                  : () {
                      _session.skip();
                      setState(() {
                        _outcome = null;
                        _answeredQuestion = null;
                      });
                      _lastQuestionId = null;
                      _onChanged();
                    },
              icon: const Icon(Icons.skip_next),
            ),
          if (!_session.isLoading && !_session.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_session.position}/${_session.total}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
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
                child: ErrorBanner(message: _session.error!, onRetry: _start),
              ),
            Expanded(child: _buildBody(theme)),
            if (!_session.isLoading &&
                !_session.isEmpty &&
                !_session.isFinished)
              _AnswerArea(
                kind: widget.kind,
                controller: _controller,
                focusNode: _focus,
                busy: _session.isBusy,
                answered: _outcome != null,
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
  }

  Widget _buildBody(ThemeData theme) {
    if (_session.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_session.isEmpty) {
      return EmptyState(
        icon: Icons.school_outlined,
        title: _session.error == null ? '没有可练习的单词' : '练习无法开始',
        message: widget.kind == PracticeKind.cloze
            ? '例句挖空只使用词条自带的例句；没有例句的词不会进入练习。可以先补充例句或改用其他练习方式。'
            : '练习需要带中文释义的词条。先导入或添加单词后再回来。',
        action: ElevatedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('返回'),
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
    final PracticeQuestion? question = _answeredQuestion ?? _session.current;
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
              outcome: _outcome,
              onSpeak: () => _speak(question.answer),
              onChoice: _outcome == null ? _submitChoice : null,
            ),
            if (_outcome != null) ...<Widget>[
              AppSpacing.h16,
              _FeedbackCard(outcome: _outcome!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _restartSession() async {
    setState(() {
      _outcome = null;
      _answeredQuestion = null;
      _lastQuestionId = null;
    });
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
              tooltip: '再听一次',
              iconSize: 56,
              onPressed: onSpeak,
              icon: Icon(Icons.volume_up, color: theme.colorScheme.primary),
            ),
          ),
          Center(child: Text('听发音，输入单词', style: theme.textTheme.bodySmall)),
          AppSpacing.h12,
        ],
        if (question.kind == PracticeKind.cloze)
          SelectableText(
            question.prompt,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              height: 1.6,
            ),
          )
        else
          SelectableText(
            question.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(height: 1.4),
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
                  minimumSize: const Size.fromHeight(48),
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
              '提示：${question.word.translation}',
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
        borderRadius: BorderRadius.circular(AppDimens.radius),
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
                outcome.correct ? '正确' : '不正确',
                style: theme.textTheme.titleSmall?.copyWith(color: color),
              ),
            ],
          ),
          AppSpacing.h8,
          SelectableText('正确拼写：${outcome.answer}'),
          if (!outcome.correct && outcome.submitted.trim().isNotEmpty)
            Text(
              '你的答案：${outcome.submitted.trim()}',
              style: theme.textTheme.bodySmall,
            ),
          Text('本次练习只记录作答，不会改变该词的长期复习间隔。', style: theme.textTheme.bodySmall),
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
  final bool showHint;
  final VoidCallback onToggleHint;
  final Future<void> Function() onSubmit;
  final VoidCallback onNext;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: answered
            ? SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNext,
                  child: const Text('下一题'),
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
                          isDense: true,
                          hintText: '输入英文单词',
                          suffixIcon: onSpeak == null
                              ? null
                              : IconButton(
                                  tooltip: '再听一次',
                                  onPressed: onSpeak,
                                  icon: const Icon(Icons.volume_up_outlined),
                                ),
                        ),
                      ),
                    ),
                    AppSpacing.w8,
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: busy ? null : onSubmit,
                        child: const Text('提交'),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: Text(
                        '从上面选择你认为正确的单词',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (kind == PracticeKind.dictation) ...<Widget>[
                    IconButton(
                      tooltip: showHint ? '隐藏中文提示' : '显示中文提示',
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
                '本组练习完成',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              AppSpacing.h24,
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatBlock(
                      value: '${summary.answered}',
                      label: '实际作答',
                    ),
                  ),
                  Expanded(
                    child: StatBlock(value: '${summary.correct}', label: '正确'),
                  ),
                  Expanded(
                    child: StatBlock(value: '${summary.skipped}', label: '跳过'),
                  ),
                ],
              ),
              AppSpacing.h12,
              Text(
                '正确率：${summary.accuracy == null ? '—' : '${(summary.accuracy! * 100).toStringAsFixed(1)}%'}'
                '（${summary.uniqueWords} 个单词）',
                textAlign: TextAlign.center,
              ),
              if (summary.wrongWords.isNotEmpty) ...<Widget>[
                AppSpacing.h16,
                Text('需要再看一遍', style: theme.textTheme.titleSmall),
                AppSpacing.h8,
                SelectableText(summary.wrongWords.join(' · ')),
              ],
              AppSpacing.h12,
              Text(
                '练习作答计入统计，但不会改变长期复习间隔。',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              AppSpacing.h24,
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onAgain,
                      child: const Text('再来一组'),
                    ),
                  ),
                  AppSpacing.w8,
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onDone,
                      child: const Text('返回'),
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
