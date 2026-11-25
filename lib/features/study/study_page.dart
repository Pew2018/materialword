import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_models.dart';
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

class _StudyPageState extends ConsumerState<StudyPage> {
  late final StudySession _session;
  final ScrollController _scroll = ScrollController();
  bool _started = false;
  String? _lastCardId;
  StudySettingsRow? _settings;
  late final TtsService _tts;
  Future<StudyRoundSummary>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    // Resolved eagerly: `ref` must not be touched in dispose().
    _tts = ref.read(ttsServiceProvider);
    _session = StudySession(
      ref.read(studyRepositoryProvider),
      ref.read(settingsRepositoryProvider),
      ref.read(clockProvider),
    )..addListener(_onSessionChanged);
    _start();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _scroll.dispose();
    // Captured in initState: `ref` must not be used while disposing.
    _tts.stop();
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
    final String? id = card?.word.id;
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
      final String message = _tts.lastError ?? '系统语音不可用';
      showMessage(context, message, error: true);
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
    return AnimatedBuilder(
      animation: _session,
      builder: (BuildContext context, Widget? _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(
                value: _session.progress,
                minHeight: 3,
                backgroundColor: Colors.black26,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onPrimary,
                ),
              ),
            ),
            actions: <Widget>[
              if (_session.current != null && !_session.isFinished)
                IconButton(
                  tooltip: '编辑当前词条',
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
              if (_session.current != null && !_session.isLoading)
                IconButton(
                  tooltip: '跳过（不计入作答）',
                  icon: const Icon(Icons.skip_next),
                  onPressed: _session.isBusy ? null : _session.skip,
                ),
              IconButton(
                tooltip: '撤销上一作答',
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
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
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
              child: Column(
                children: <Widget>[
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
        );
      },
    );
  }

  String get _title {
    if (widget.special != SpecialReview.none) return widget.special.label;
    if (widget.reviewOnly) return '复习';
    return '学习';
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
              Text(_session.error!, textAlign: TextAlign.center),
              AppSpacing.h16,
              ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }
    if (_session.isEmpty) {
      return EmptyState(
        icon: Icons.done_all,
        title: widget.special != SpecialReview.none
            ? '该专项暂时没有需要复习的单词'
            : '今天没有需要学习的单词',
        message: widget.special != SpecialReview.none
            ? '专项复习只包含符合当前条件的单词，普通复习队列不受影响。'
            : '今日可学的新词和到期复习都已处理完。可以调整每日目标、导入新词，或稍后回来。',
        action: ElevatedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('返回'),
        ),
      );
    }
    if (_session.isFinished) {
      return FutureBuilder<StudyRoundSummary>(
        future: _summaryFuture ??= _session.summary(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorBanner(
              message: '读取本轮统计失败',
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
              tooltip: '朗读',
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
                    tts.lastError ?? '系统语音不可用，可继续用默读方式学习',
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
              const TagChip(label: '本次重复', color: AppColors.hazy, dense: true),
            if (card.type == ReviewType.study)
              const TagChip(label: '新词', dense: true)
            else
              TagChip(
                label: '复习 · ${StudyStage.fromCode(state?.stage ?? 0).label}',
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
                label: '错 ${state!.wrongCount} 次',
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
                Text('先回想，再显示释义', style: theme.textTheme.bodySmall),
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
            word.translation.isEmpty ? '（暂无中文释义，可在词条中补充）' : word.translation,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 17,
              height: 1.6,
            ),
          ),
          if (word.definition.isNotEmpty) ...<Widget>[
            AppSpacing.h12,
            _DisclosureSection(
              title: '英文释义',
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
            _LabeledBlock(label: '例句', child: word.example, italic: true),
          ],
          if (word.phrase.isNotEmpty) ...<Widget>[
            AppSpacing.h12,
            _LabeledBlock(label: '短语', child: word.phrase),
          ],
          if (word.note.isNotEmpty) ...<Widget>[
            AppSpacing.h12,
            _LabeledBlock(label: '笔记', child: word.note),
          ],
          if (state != null) ...<Widget>[
            AppSpacing.h16,
            Text(
              '正确 ${state.correctCount} · 模糊 ${state.hazyCount} · 错误 ${state.wrongCount}'
              ' · 间隔 ${state.intervalDays} 天',
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
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: revealed
              ? Row(
                  children: <Widget>[
                    _AnswerButton(
                      label: AnswerResult.unknown.label,
                      color: AppColors.unknown,
                      shortcut: desktop ? '1' : null,
                      onPressed: busy
                          ? null
                          : () => onAnswer(AnswerResult.unknown),
                    ),
                    AppSpacing.w8,
                    _AnswerButton(
                      label: AnswerResult.hazy.label,
                      color: AppColors.hazy,
                      shortcut: desktop ? '2' : null,
                      onPressed: busy
                          ? null
                          : () => onAnswer(AnswerResult.hazy),
                    ),
                    AppSpacing.w8,
                    _AnswerButton(
                      label: AnswerResult.known.label,
                      color: AppColors.known,
                      shortcut: desktop ? '3' : null,
                      onPressed: busy
                          ? null
                          : () => onAnswer(AnswerResult.known),
                    ),
                  ],
                )
              : SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onReveal,
                    child: Text(desktop ? '显示释义（Space）' : '显示释义'),
                  ),
                ),
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
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radius),
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
                '本组完成',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              AppSpacing.h24,
              Row(
                children: <Widget>[
                  Expanded(
                    child: StatBlock(
                      value: '${summary.newWords}',
                      label: '新词（独立）',
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      value: '${summary.reviewWords}',
                      label: '复习（独立）',
                    ),
                  ),
                  Expanded(
                    child: StatBlock(
                      value: '${summary.repeatAttempts}',
                      label: '复练作答',
                    ),
                  ),
                ],
              ),
              AppSpacing.h16,
              Text(
                '共 ${summary.uniqueWords} 个独立单词，${summary.attempts} 次实际作答',
                textAlign: TextAlign.center,
              ),
              AppSpacing.h12,
              Row(
                children: [
                  Expanded(
                    child: StatBlock(value: '${summary.known}', label: '认识'),
                  ),
                  Expanded(
                    child: StatBlock(value: '${summary.hazy}', label: '模糊'),
                  ),
                  Expanded(
                    child: StatBlock(value: '${summary.unknown}', label: '不认识'),
                  ),
                ],
              ),
              AppSpacing.h12,
              Text(
                '本轮正确率：${summary.accuracy == null ? '—' : '${(summary.accuracy! * 100).toStringAsFixed(1)}%'}',
                textAlign: TextAlign.center,
              ),
              Text(
                '经过时间：${summary.elapsed.inMinutes} 分 ${summary.elapsed.inSeconds % 60} 秒（含暂停）',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (summary.difficultWords.isNotEmpty) ...[
                AppSpacing.h16,
                Text('本轮困难词', style: theme.textTheme.titleSmall),
                AppSpacing.h8,
                SelectableText(
                  summary.difficultWords
                      .map((w) => '${w.word}${w.available ? '' : '（已删除）'}')
                      .join(' · '),
                ),
                Text(
                  '包含本轮曾模糊或不认识的单词；已删除词不进入复练。',
                  style: theme.textTheme.bodySmall,
                ),
                AppSpacing.h12,
                OutlinedButton.icon(
                  onPressed: onMistakes,
                  icon: const Icon(Icons.replay),
                  label: const Text('复练本轮错词'),
                ),
              ],
              if (backlog > 0) ...<Widget>[
                AppSpacing.h16,
                Text(
                  '还有 $backlog 个到期单词顺延到明天。',
                  style: theme.textTheme.bodySmall,
                ),
              ],
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
