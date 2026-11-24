import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/models/study_models.dart';
import '../../services/study_session.dart';
import '../../shared/widgets/common.dart';

/// Learning / review screen. One word at a time, three answer levels, keyboard
/// driven on desktop.
class StudyPage extends ConsumerStatefulWidget {
  const StudyPage({super.key, this.reviewOnly = false});

  final bool reviewOnly;

  @override
  ConsumerState<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends ConsumerState<StudyPage> {
  late final StudySession _session;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _session = StudySession(
      ref.read(studyRepositoryProvider),
      ref.read(settingsRepositoryProvider),
      ref.read(clockProvider),
    );
    _start();
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    final StudySettingsRow settings = await ref
        .read(settingsRepositoryProvider)
        .load();
    final DateTime now = ref.read(clockProvider).now();
    final int newDone = await ref
        .read(studyRepositoryProvider)
        .todayCount(now: now, type: ReviewType.study);
    final int reviewDone = await ref
        .read(studyRepositoryProvider)
        .todayCount(now: now, type: ReviewType.review);
    await _session.load(
      newLimit: (settings.dailyNewTarget - newDone).clamp(
        0,
        settings.dailyNewTarget,
      ),
      reviewLimit: (settings.dailyReviewLimit - reviewDone).clamp(
        0,
        settings.dailyReviewLimit,
      ),
      bookId: settings.currentWordBookId,
      mode: widget.reviewOnly
          ? StudyMode.reviewOnly
          : StudyMode.fromCode(settings.studyMode),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  Future<void> _answer(AnswerResult result) async {
    await _session.submit(result);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (BuildContext context, Widget? _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.reviewOnly ? '复习' : '学习'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: _session.progress,
                minHeight: 4,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            actions: <Widget>[
              if (!_session.isLoading && !_session.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Text(
                      '${_session.position}/${_session.totalCards}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
          body: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.space): _session.reveal,
              const SingleActivator(LogicalKeyboardKey.digit1): () =>
                  _answer(AnswerResult.unknown),
              const SingleActivator(LogicalKeyboardKey.digit2): () =>
                  _answer(AnswerResult.hazy),
              const SingleActivator(LogicalKeyboardKey.digit3): () =>
                  _answer(AnswerResult.known),
              const SingleActivator(LogicalKeyboardKey.enter): () {
                if (!_session.isRevealed) _session.reveal();
              },
            },
            child: Focus(autofocus: true, child: _buildBody(context)),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
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
                size: 48,
                color: AppColors.unknown,
              ),
              AppSpacing.h16,
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
      final int remaining = _session.newAvailable + _session.reviewAvailable;
      return EmptyState(
        icon: Icons.done_all,
        title: '今天没有需要学习的单词',
        message: remaining == 0
            ? '今日目标已完成。可以调整每日目标、导入新词书，或稍后回来复习。'
            : '本次队列为空，请检查每日新词目标与复习上限设置。',
        action: ElevatedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('返回'),
        ),
      );
    }
    if (_session.isFinished) {
      return _SummaryView(
        newAnswered: _session.newAnswered,
        reviewAnswered: _session.reviewAnswered,
        repeats: _session.repeatCards,
        backlog: _session.backlog,
        onDone: () => Navigator.of(context).maybePop(),
        onAgain: () async {
          _started = false;
          await _start();
        },
      );
    }

    final StudyCard card = _session.current!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.gutter),
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _WordCard(card: card, revealed: _session.isRevealed),
            AppSpacing.h24,
            if (!_session.isRevealed)
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _session.reveal,
                  child: const Text('显示释义（Space）'),
                ),
              )
            else
              _AnswerButtons(onAnswer: _answer, busy: _session.isBusy),
            AppSpacing.h16,
            Center(
              child: Text(
                '快捷键：Space 显示释义 · 1 不认识 · 2 模糊 · 3 认识',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.card, required this.revealed});

  final StudyCard card;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Word word = card.word;
    final LearningState? state = card.withState.state;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              word.word,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            if (word.phonetic.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '/${word.phonetic}/',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (card.repeatCount > 0) ...<Widget>[
                  const TagChip(label: '本次重复', color: AppColors.hazy),
                  AppSpacing.w8,
                ],
                if (card.type == ReviewType.study)
                  const TagChip(label: '新词')
                else
                  TagChip(
                    label:
                        '复习 · ${StudyStage.fromCode(state?.stage ?? 0).label}',
                    color: AppColors.hazy,
                  ),
                if (word.examTags.isNotEmpty) ...<Widget>[
                  AppSpacing.w8,
                  TagChip(
                    label: word.examTags
                        .split(' ')
                        .take(2)
                        .join(' ')
                        .toUpperCase(),
                    dense: true,
                  ),
                ],
              ],
            ),
            if (revealed) ...<Widget>[
              const Divider(height: 32),
              if (word.partOfSpeech.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    word.partOfSpeech,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              SelectableText(
                word.translation.isEmpty
                    ? '（暂无中文释义，可在词条中补充）'
                    : word.translation,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
              if (word.definition.isNotEmpty) ...<Widget>[
                AppSpacing.h12,
                SelectableText(
                  word.definition,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                    height: 1.4,
                  ),
                ),
              ],
              if (word.example.isNotEmpty) ...<Widget>[
                AppSpacing.h16,
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(AppDimens.radius),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: SelectableText(
                    word.example,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (word.note.isNotEmpty) ...<Widget>[
                AppSpacing.h12,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const TagChip(label: '笔记', color: AppColors.primary),
                    AppSpacing.w8,
                    Expanded(
                      child: SelectableText(
                        word.note,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
              if (state != null) ...<Widget>[
                AppSpacing.h16,
                Text(
                  '正确 ${state.correctCount} · 模糊 ${state.hazyCount} · 错误 ${state.wrongCount}'
                  ' · 连续正确 ${state.streak} · 间隔 ${state.intervalDays} 天',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerButtons extends StatelessWidget {
  const _AnswerButtons({required this.onAnswer, required this.busy});

  final Future<void> Function(AnswerResult result) onAnswer;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    Widget button(AnswerResult result, Color color, String shortcut) {
      return Expanded(
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: busy ? null : () => onAnswer(result),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radius),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  result.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  shortcut,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        button(AnswerResult.unknown, AppColors.unknown, '1'),
        AppSpacing.w12,
        button(AnswerResult.hazy, AppColors.hazy, '2'),
        AppSpacing.w12,
        button(AnswerResult.known, AppColors.known, '3'),
      ],
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.newAnswered,
    required this.reviewAnswered,
    required this.repeats,
    required this.backlog,
    required this.onDone,
    required this.onAgain,
  });

  final int newAnswered;
  final int reviewAnswered;
  final int repeats;
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
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  AppSpacing.h16,
                  Text(
                    '本组完成',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  AppSpacing.h24,
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: StatBlock(value: '$newAnswered', label: '新词'),
                      ),
                      Expanded(
                        child: StatBlock(value: '$reviewAnswered', label: '复习'),
                      ),
                      Expanded(
                        child: StatBlock(value: '$repeats', label: '重复练习'),
                      ),
                    ],
                  ),
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
                      AppSpacing.w12,
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onDone,
                          child: const Text('返回首页'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
