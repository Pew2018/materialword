import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/l10n.dart';
import '../../l10n/relative_time.dart';
import '../../l10n/source_labels.dart';
import '../../core/text/dictionary_text.dart';
import '../../core/time_utils.dart';
import '../../shared/widgets/common.dart';
import 'word_metadata_widgets.dart';

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
  bool _manualMastery = false;

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
    final manualMastery = await ref
        .read(studyRepositoryProvider)
        .hasManualMastery(widget.wordId);
    if (!mounted) return;
    setState(() {
      _manualMastery = manualMastery;
      _wordRow = word;
      _state = state;
      _events = events;
      _loading = false;
      if (word != null) {
        _word.text = word.word;
        _phonetic.text = word.phonetic;
        _pos.text = word.partOfSpeech;
        // Dictionary-owned fields are shown normalised; the note is verbatim.
        _translation.text = normalizeDictionaryText(word.translation);
        _definition.text = normalizeDictionaryText(word.definition);
        _example.text = normalizeDictionaryText(word.example);
        _phrase.text = normalizeDictionaryText(word.phrase);
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
      showMessage(context, context.l10n.saved);
      await _load();
    } catch (e) {
      if (mounted) {
        showMessage(context, context.l10n.errorSaveFailed, error: true);
      }
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
      showMessage(context, context.l10n.wordNotInDictionary);
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
    showMessage(context, context.l10n.filledFromDictionary);
  }

  Future<void> _markMastered({bool undo = false}) async {
    final bool ok = await confirmDialog(
      context,
      title: undo
          ? context.l10n.unmarkMasteredTitle
          : context.l10n.markMasteredTitle,
      message: undo
          ? context.l10n.unmarkMasteredBody
          : context.l10n.markMasteredBodyOne,
      confirmLabel: undo
          ? context.l10n.unmarkMastered
          : context.l10n.markMastered,
    );
    if (!ok || !mounted) return;
    final String device = await ref.read(settingsRepositoryProvider).deviceId();
    final repo = ref.read(studyRepositoryProvider);
    await (undo ? repo.unmarkMastered : repo.markMastered)(
      wordId: widget.wordId,
      deviceId: device,
      now: ref.read(clockProvider).now(),
      eventId: const Uuid().v4(),
    );
    ref.invalidate(todayProgressProvider);
    ref.invalidate(statisticsProvider);
    if (mounted) await _load();
  }

  Future<void> _resetProgress() async {
    final bool ok = await confirmDialog(
      context,
      title: context.l10n.resetProgressTitle,
      message: context.l10n.resetProgressBodyOne,
      confirmLabel: context.l10n.reset,
      destructive: true,
    );
    if (!ok) return;
    final String device = await ref.read(settingsRepositoryProvider).deviceId();
    await ref
        .read(studyRepositoryProvider)
        .resetProgress(
          wordId: widget.wordId,
          deviceId: device,
          now: ref.read(clockProvider).now(),
          eventId: const Uuid().v4(),
        );
    ref.invalidate(todayProgressProvider);
    ref.invalidate(statisticsProvider);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: ClassicAppBar(title: Text(context.l10n.wordEntry)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_wordRow == null) {
      return Scaffold(
        appBar: ClassicAppBar(title: Text(context.l10n.wordEntry)),
        body: EmptyState(
          icon: Icons.search_off,
          title: context.l10n.wordNotFound,
        ),
      );
    }

    return Scaffold(
      appBar: ClassicAppBar(
        title: Text(_wordRow!.word),
        actions: <Widget>[
          FavoriteButton(wordId: widget.wordId),
          PopupMenuButton<String>(
            onSelected: (String value) async {
              switch (value) {
                case 'dict':
                  await _fillFromDictionary();
                case 'mastered':
                  await _markMastered();
                case 'unmastered':
                  await _markMastered(undo: true);
                case 'reset':
                  await _resetProgress();
                case 'remove':
                  if (widget.bookId == null) return;
                  final bool ok = await confirmDialog(
                    context,
                    title: context.l10n.removeFromWordList,
                    message: context.l10n.removeFromListBodyWord(
                      _wordRow!.word,
                    ),
                    confirmLabel: context.l10n.commonRemove,
                    destructive: true,
                  );
                  if (!ok) return;
                  await ref
                      .read(wordBookRepositoryProvider)
                      .removeWord(
                        widget.bookId!,
                        widget.wordId,
                        now: ref.read(clockProvider).now(),
                      );
                  ref.invalidate(bookSummariesProvider);
                  ref.invalidate(todayProgressProvider);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                case 'delete':
                  final bool ok = await confirmDialog(
                    context,
                    title: context.l10n.wordManagementDeleteWord,
                    message: context.l10n.deleteWordBodyName(_wordRow!.word),
                    confirmLabel: context.l10n.commonDelete,
                    destructive: true,
                  );
                  if (!ok) return;
                  await ref
                      .read(wordRepositoryProvider)
                      .softDelete(
                        widget.wordId,
                        now: ref.read(clockProvider).now(),
                      );
                  ref.invalidate(bookSummariesProvider);
                  ref.invalidate(statisticsProvider);
                  ref.invalidate(todayProgressProvider);
                  if (context.mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'dict',
                child: Text(context.l10n.fillFromDictionary),
              ),
              PopupMenuItem<String>(
                value: _manualMastery ? 'unmastered' : 'mastered',
                child: Text(
                  _manualMastery
                      ? context.l10n.unmarkMastered
                      : context.l10n.markMastered,
                ),
              ),
              PopupMenuItem<String>(
                value: 'reset',
                child: Text(context.l10n.resetProgress),
              ),
              if (widget.bookId != null)
                PopupMenuItem<String>(
                  value: 'remove',
                  child: Text(context.l10n.removeFromCurrentList),
                ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(context.l10n.wordManagementDeleteWord),
              ),
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
                WordTagsEditor(wordId: widget.wordId),
                _StateCard(word: _wordRow!, state: _state),
                AppSpacing.h16,
                SectionCard(
                  title: context.l10n.wordInfo,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _word,
                        decoration: InputDecoration(
                          labelText: context.l10n.wordField,
                        ),
                      ),
                      AppSpacing.h12,
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _phonetic,
                              decoration: InputDecoration(
                                labelText: context.l10n.phonetics,
                              ),
                            ),
                          ),
                          AppSpacing.w12,
                          Expanded(
                            child: TextField(
                              controller: _pos,
                              decoration: InputDecoration(
                                labelText: context.l10n.partOfSpeech,
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
                        decoration: InputDecoration(
                          labelText: context.l10n.chineseMeaning,
                        ),
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: _definition,
                        minLines: 2,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: context.l10n.englishDefinition,
                        ),
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: _example,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: context.l10n.exampleSentence,
                        ),
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: _phrase,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: context.l10n.phrases,
                        ),
                      ),
                      AppSpacing.h12,
                      TextField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: context.l10n.notes,
                        ),
                      ),
                      AppSpacing.h16,
                      Text(
                        context.l10n.savedAsCustom,
                        style: theme.textTheme.bodySmall,
                      ),
                      AppSpacing.h16,
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving
                                ? context.l10n.saving
                                : context.l10n.commonSave,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.h16,
                SectionCard(
                  title: context.l10n.answerHistory(_events.length),
                  child: _events.isEmpty
                      ? Text(
                          context.l10n.noAnswerHistory,
                          style: theme.textTheme.bodySmall,
                        )
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
                                          .label(context.l10n),
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
                                          ? context.l10n.eventNewStudy
                                          : context.l10n.eventReview,
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
      title: context.l10n.learningProgress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              TagChip(label: stage.label(context.l10n)),
              if (word.customized)
                TagChip(label: context.l10n.editedTag, color: AppColors.known),
              if (word.examTags.isNotEmpty)
                TagChip(label: word.examTags.toUpperCase(), dense: true),
              if (word.source.isNotEmpty)
                TagChip(
                  label: context.l10n.sourceLabel(
                    wordSourceLabel(context.l10n, word.source),
                  ),
                  dense: true,
                ),
            ],
          ),
          AppSpacing.h16,
          Row(
            children: <Widget>[
              Expanded(
                child: StatBlock(
                  value: '${state?.correctCount ?? 0}',
                  label: AnswerResult.known.label(context.l10n),
                ),
              ),
              Expanded(
                child: StatBlock(
                  value: '${state?.hazyCount ?? 0}',
                  label: AnswerResult.hazy.label(context.l10n),
                  color: AppColors.hazy,
                ),
              ),
              Expanded(
                child: StatBlock(
                  value: '${state?.wrongCount ?? 0}',
                  label: AnswerResult.unknown.label(context.l10n),
                  color: AppColors.unknown,
                ),
              ),
              Expanded(
                child: StatBlock(
                  value: context.l10n.intervalDays(state?.intervalDays ?? 0),
                  label: context.l10n.intervalLabel,
                ),
              ),
            ],
          ),
          if (next != null) ...<Widget>[
            AppSpacing.h12,
            Text(
              context.l10n.nextReviewAt(
                formatDateTime(next),
                relativeTime(next, DateTime.now(), context.l10n),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
