import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/time_utils.dart';
import '../../shared/widgets/common.dart';

/// Edit one word: meaning, phonetic, examples, personal note — plus its current
/// learning state and raw answer history.
class WordDetailPage extends ConsumerStatefulWidget {
  const WordDetailPage({super.key, required this.wordId, this.bookId});

  final String wordId;
  final String? bookId;

  @override
  ConsumerState<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends ConsumerState<WordDetailPage> {
  final TextEditingController _word = TextEditingController();
  final TextEditingController _phonetic = TextEditingController();
  final TextEditingController _pos = TextEditingController();
  final TextEditingController _translation = TextEditingController();
  final TextEditingController _definition = TextEditingController();
  final TextEditingController _example = TextEditingController();
  final TextEditingController _phrase = TextEditingController();
  final TextEditingController _note = TextEditingController();

  Word? _wordRow;
  LearningState? _state;
  List<ReviewEvent> _events = const <ReviewEvent>[];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _word,
      _phonetic,
      _pos,
      _translation,
      _definition,
      _example,
      _phrase,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final Word? word = await ref
        .read(wordRepositoryProvider)
        .byId(widget.wordId);
    final LearningState? state = await ref
        .read(wordRepositoryProvider)
        .stateFor(widget.wordId);
    final List<ReviewEvent> events = await ref
        .read(wordRepositoryProvider)
        .eventsForWord(widget.wordId);
    if (!mounted) return;
    setState(() {
      _wordRow = word;
      _state = state;
      _events = events;
      _loading = false;
      if (word != null) {
        _word.text = word.word;
        _phonetic.text = word.phonetic;
        _pos.text = word.partOfSpeech;
        _translation.text = word.translation;
        _definition.text = word.definition;
        _example.text = word.example;
        _phrase.text = word.phrase;
        _note.text = word.note;
      }
    });
  }

  Future<void> _save() async {
    if (_wordRow == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(wordRepositoryProvider)
          .updateContent(
            widget.wordId,
            text: _word.text,
            phonetic: _phonetic.text,
            partOfSpeech: _pos.text,
            translation: _translation.text,
            definition: _definition.text,
            example: _example.text,
            phrase: _phrase.text,
            note: _note.text,
            now: ref.read(clockProvider).now(),
          );
      ref.invalidate(statisticsProvider);
      ref.invalidate(bookSummariesProvider);
      if (!mounted) return;
      showMessage(context, '已保存');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, '保存失败：$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _fillFromDictionary() async {
    final Word? word = _wordRow;
    if (word == null) return;
    final dictionary = await ref.read(dictionaryProvider.future);
    final entry = await dictionary.lookup(word.word);
    if (!mounted) return;
    if (entry == null) {
      showMessage(context, '离线词典未收录该单词');
      return;
    }
    setState(() {
      if (_phonetic.text.trim().isEmpty) _phonetic.text = entry.phonetic;
      if (_pos.text.trim().isEmpty) _pos.text = entry.partOfSpeech;
      if (_translation.text.trim().isEmpty) {
        _translation.text = entry.translation;
      }
      if (_definition.text.trim().isEmpty) _definition.text = entry.definition;
    });
    showMessage(context, '已用词典补全空白字段，记得保存');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('词条')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_wordRow == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('词条')),
        body: const EmptyState(icon: Icons.search_off, title: '词条不存在或已被删除'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_wordRow!.word),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String value) async {
              if (value == 'dict') await _fillFromDictionary();
              if (value == 'remove' && widget.bookId != null) {
                if (!context.mounted) return;
                final bool ok = await confirmDialog(
                  context,
                  title: '移出词书',
                  message: '把「${_wordRow!.word}」从当前词书移除？学习记录会保留。',
                  confirmLabel: '移出',
                  destructive: true,
                );
                if (ok) {
                  await ref
                      .read(wordBookRepositoryProvider)
                      .removeWord(widget.bookId!, widget.wordId);
                  ref.invalidate(bookSummariesProvider);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                }
              }
              if (value == 'delete') {
                if (!context.mounted) return;
                final bool ok = await confirmDialog(
                  context,
                  title: '删除单词',
                  message:
                      '删除「${_wordRow!.word}」？原始作答记录仍然保留在数据库中，导出备份时也会带上删除标记。',
                  confirmLabel: '删除',
                  destructive: true,
                );
                if (ok) {
                  await ref
                      .read(wordRepositoryProvider)
                      .softDelete(
                        widget.wordId,
                        now: ref.read(clockProvider).now(),
                      );
                  ref.invalidate(bookSummariesProvider);
                  ref.invalidate(statisticsProvider);
                  if (context.mounted) Navigator.of(context).pop();
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'dict',
                child: Text('用离线词典补全空白'),
              ),
              if (widget.bookId != null)
                const PopupMenuItem<String>(
                  value: 'remove',
                  child: Text('移出当前词书'),
                ),
              const PopupMenuItem<String>(value: 'delete', child: Text('删除单词')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.gutter),
        children: <Widget>[
          ContentWidth(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _StateCard(word: _wordRow!, state: _state),
                AppSpacing.h16,
                SectionCard(
                  title: '词条内容',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _word,
                        decoration: const InputDecoration(labelText: '单词'),
                      ),
                      AppSpacing.h12,
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _phonetic,
                              decoration: const InputDecoration(
                                labelText: '音标',
                              ),
                            ),
                          ),
                          AppSpacing.w12,
                          Expanded(
                            child: TextField(
                              controller: _pos,
                              decoration: const InputDecoration(
                                labelText: '词性',
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: _translation,
                        minLines: 2,
                        maxLines: 6,
                        decoration: const InputDecoration(labelText: '中文释义'),
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: _definition,
                        minLines: 2,
                        maxLines: 6,
                        decoration: const InputDecoration(labelText: '英文释义'),
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: _example,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(labelText: '例句'),
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: _phrase,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: '短语 / 搭配'),
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 6,
                        decoration: const InputDecoration(labelText: '个人笔记'),
                      ),
                      AppSpacing.h16,
                      Text(
                        '保存后该词条标记为用户自定义，词典更新不会覆盖你填写的内容。',
                        style: theme.textTheme.bodySmall,
                      ),
                      AppSpacing.h16,
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: Text(_saving ? '保存中…' : '保存修改'),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.h16,
                SectionCard(
                  title: '作答历史（${_events.length}）',
                  child: _events.isEmpty
                      ? Text('还没有作答记录。', style: theme.textTheme.bodySmall)
                      : Column(
                          children: <Widget>[
                            for (final ReviewEvent event in _events.take(20))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    TagChip(
                                      label: AnswerResult.fromCode(event.result)
                                          .label,
                                      color: switch (AnswerResult.fromCode(
                                        event.result,
                                      )) {
                                        AnswerResult.known => AppColors.known,
                                        AnswerResult.hazy => AppColors.hazy,
                                        AnswerResult.unknown =>
                                          AppColors.unknown,
                                      },
                                      dense: true,
                                    ),
                                    AppSpacing.w8,
                                    Text(
                                      ReviewType.fromCode(event.type) ==
                                              ReviewType.study
                                          ? '新词学习'
                                          : '复习',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const Spacer(),
                                    Text(
                                      formatDateTime(
                                        DateTime.fromMillisecondsSinceEpoch(
                                          event.answeredAt,
                                          isUtc: true,
                                        ),
                                      ),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.word, required this.state});

  final Word word;
  final LearningState? state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final StudyStage stage = StudyStage.fromCode(state?.stage ?? 0);
    final DateTime? next = state?.nextReviewAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            state!.nextReviewAt!,
            isUtc: true,
          ).toLocal();
    return SectionCard(
      title: '学习状态',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              TagChip(label: stage.label),
              if (word.customized)
                const TagChip(label: '用户自定义', color: AppColors.known),
              if (word.examTags.isNotEmpty)
                TagChip(label: word.examTags.toUpperCase(), dense: true),
              if (word.source.isNotEmpty)
                TagChip(label: '来源：${word.source}', dense: true),
            ],
          ),
          AppSpacing.h16,
          Row(
            children: <Widget>[
              Expanded(
                child: StatBlock(
                  value: '${state?.correctCount ?? 0}',
                  label: '正确',
                ),
              ),
              Expanded(
                child: StatBlock(
                  value: '${state?.hazyCount ?? 0}',
                  label: '模糊',
                  color: AppColors.hazy,
                ),
              ),
              Expanded(
                child: StatBlock(
                  value: '${state?.wrongCount ?? 0}',
                  label: '错误',
                  color: AppColors.unknown,
                ),
              ),
              Expanded(
                child: StatBlock(
                  value: '${state?.intervalDays ?? 0} 天',
                  label: '当前间隔',
                ),
              ),
            ],
          ),
          if (next != null) ...<Widget>[
            AppSpacing.h12,
            Text(
              '下次复习：${formatDateTime(next)}（${relativeTime(next, DateTime.now())}）',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
