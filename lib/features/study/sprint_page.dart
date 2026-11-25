import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/errors/app_error.dart';
import '../../l10n/error_labels.dart';
import '../../l10n/l10n.dart';
import '../../core/database/app_database.dart';
import '../../core/models/enums.dart';
import '../../core/models/sprint_plan.dart';
import '../../shared/widgets/classic_select.dart';
import '../../shared/widgets/common.dart';
import 'study_page.dart';

class SprintPage extends ConsumerStatefulWidget {
  const SprintPage({super.key});
  @override
  ConsumerState<SprintPage> createState() => _SprintPageState();
}

class _SprintPageState extends ConsumerState<SprintPage>
    with WidgetsBindingObserver {
  SprintPlan _plan = const SprintPlan();
  SprintOverview? _overview;
  List<WordBook> _books = [];
  bool _loading = true, _busy = false;
  AppErrorCode? _error;
  int _generation = 0;
  Timer? _timer;
  Timer? _clockTimer;
  StreamSubscription<dynamic>? _data, _plans;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleClock();
    _plans = ref
        .read(settingsRepositoryProvider)
        .watchSprintPlan()
        .listen(
          (_) => _requestLoad(),
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = AppErrorCode.loadFailed;
              });
            }
          },
        );
    _data = ref.read(databaseProvider).tableUpdates().listen((updates) {
      if (updates.any(
        (u) => const {
          'words',
          'word_books',
          'word_book_entries',
          'learning_states',
          'review_events',
          'study_settings',
        }.contains(u.table),
      )) {
        _requestLoad();
      }
    });
    _load();
  }

  void _requestLoad() {
    _generation++;
    _timer?.cancel();
    if (_busy) return;
    _timer = Timer(const Duration(milliseconds: 200), _load);
  }

  void _scheduleClock() {
    _clockTimer?.cancel();
    final now = ref.read(clockProvider).now().toLocal();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _clockTimer = Timer(
      Duration(
        milliseconds: (midnight.difference(now).inMilliseconds + 100).clamp(
          50,
          3600000,
        ),
      ),
      () {
        if (mounted) {
          _requestLoad();
          _scheduleClock();
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestLoad();
      _scheduleClock();
    } else {
      _clockTimer?.cancel();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final plan = await ref.read(settingsRepositoryProvider).loadSprintPlan();
      final books = await ref.read(wordBookRepositoryProvider).listBooks();
      final overview = await ref
          .read(sprintRepositoryProvider)
          .overview(plan, ref.read(clockProvider).now());
      if (!mounted || generation != _generation) return;
      setState(() {
        _plan = plan;
        _books = books;
        _overview = overview;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = AppErrorCode.loadFailed;
        });
      }
    }
  }

  Future<void> _configure() async {
    if (_busy) return;
    if (_books.isEmpty) {
      showMessage(context, context.l10n.createListFirst);
      return;
    }
    final plan = await showDialog<SprintPlan>(
      context: context,
      builder: (_) => _SprintDialog(
        plan: _plan,
        books: _books,
        now: ref.read(clockProvider).now(),
      ),
    );
    if (plan == null || !mounted) return;
    await _save(plan);
  }

  Future<void> _save(SprintPlan plan) async {
    setState(() => _busy = true);
    try {
      await ref.read(settingsRepositoryProvider).save(sprintPlan: plan);
    } catch (_) {
      if (mounted) {
        showMessage(context, context.l10n.sprintSaveFailed, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    _timer?.cancel();
    try {
      final plan = await ref.read(settingsRepositoryProvider).loadSprintPlan();
      final overview = await ref
          .read(sprintRepositoryProvider)
          .overview(plan, ref.read(clockProvider).now());
      if (!mounted) return;
      if (overview.wordIds.isEmpty) {
        showMessage(context, context.l10n.sprintNothingToRun);
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => StudyPage(
            special: SpecialReview.sprint,
            bookIdOverride: plan.bookId,
            focusedWordIds: overview.wordIds,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        showMessage(context, context.l10n.sprintPrepareFailed, error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _generation++;
    _timer?.cancel();
    _data?.cancel();
    _plans?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = _plan.daysUntil(ref.read(clockProvider).now()),
        view = _overview;
    final book = _books.where((b) => b.id == _plan.bookId).firstOrNull;
    final resume = ref.watch(pausedSessionProvider).value;
    final continuing =
        resume?.special == SpecialReview.sprint &&
        resume?.bookId == _plan.bookId &&
        _plan.enabled &&
        (days ?? -1) >= 0;
    return Scaffold(
      appBar: ClassicAppBar(
        title: Text(context.l10n.specialSprint),
        actions: [
          IconButton(
            tooltip: context.l10n.setSprintPlan,
            icon: const Icon(Icons.tune),
            onPressed: _busy ? null : _configure,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    ErrorBanner(
                      message: describeAppError(context.l10n, _error!),
                      onRetry: _load,
                    ),
                  if (_busy) const LinearProgressIndicator(),
                  Text(
                    _plan.examDate == null
                        ? context.l10n.sprintTileOff
                        : days! < 0
                        ? context.l10n.examPassedDays(-days)
                        : days == 0
                        ? context.l10n.examToday
                        : context.l10n.examInDays(days),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  AppSpacing.h8,
                  Text(
                    context.l10n.targetListName(
                      book?.name ?? context.l10n.notSet,
                    ),
                  ),
                  if (!_plan.enabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(context.l10n.sprintDisabledNote),
                    ),
                  if (_plan.bookId != null && view?.bookAvailable == false)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(context.l10n.sprintBookUnavailable),
                    ),
                  if (view != null) ...[
                    AppSpacing.h24,
                    Row(
                      children: [
                        Expanded(
                          child: StatBlock(
                            value: '${view.unlearned}',
                            label: context.l10n.unlearnedWords,
                          ),
                        ),
                        Expanded(
                          child: StatBlock(
                            value: '${view.hard}',
                            label: context.l10n.difficultWords,
                          ),
                        ),
                        Expanded(
                          child: StatBlock(
                            value: '${view.recentMistakes}',
                            label: context.l10n.recentMistakes7d,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h24,
                    Text(
                      context.l10n.sprintThisRound(view.wordIds.length),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      context.l10n.sprintEligibleLine(
                        view.eligible,
                        view.reviewAllowance,
                      ),
                    ),
                    if (!_plan.includeUnlearned &&
                        view.eligible == 0 &&
                        view.unlearned > 0)
                      Text(context.l10n.sprintOnlyUnlearned),
                    if (!_plan.allowOverReviewLimit &&
                        view.reviewAllowance == 0)
                      Text(context.l10n.sprintLimitReached),
                  ],
                  AppSpacing.h16,
                  Text(context.l10n.sprintAlgorithmNote),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: Text(context.l10n.aboutSprintPlan),
                          content: Text(context.l10n.sprintAboutBody),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(context.l10n.commonClose),
                            ),
                          ],
                        ),
                      ),
                      child: Text(context.l10n.aboutSprintPlan),
                    ),
                  ),
                  AppSpacing.h24,
                  ElevatedButton.icon(
                    onPressed: _busy || view == null || view.wordIds.isEmpty
                        ? null
                        : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      continuing
                          ? context.l10n.continueSprint
                          : context.l10n.startSprint,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _configure,
                    child: Text(context.l10n.setSprintPlan),
                  ),
                  if (_plan.enabled)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _save(
                              SprintPlan.fromJson({
                                ..._plan.toJson(),
                                'enabled': false,
                              }),
                            ),
                      child: Text(context.l10n.endSprint),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SprintDialog extends StatefulWidget {
  const _SprintDialog({
    required this.plan,
    required this.books,
    required this.now,
  });
  final SprintPlan plan;
  final List<WordBook> books;
  final DateTime now;
  @override
  State<_SprintDialog> createState() => _SprintDialogState();
}

class _SprintDialogState extends State<_SprintDialog> {
  late Map<String, Object?> _values;
  late TextEditingController _size;
  AppErrorCode? _error;
  @override
  void initState() {
    super.initState();
    _values = widget.plan.toJson();
    if (!widget.books.any((b) => b.id == _values['bookId'])) {
      _values['bookId'] = null;
    }
    _size = TextEditingController(text: widget.plan.roundSize.toString());
  }

  @override
  void dispose() {
    _size.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final first = DateTime(widget.now.year - 10),
        last = DateTime(widget.now.year + 10, 12, 31);
    var initial =
        DateTime.tryParse(_values['examDate'] as String? ?? '') ?? widget.now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (date != null && mounted) {
      setState(
        () => _values['examDate'] =
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.setSprintPlan),
    scrollable: true,
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: Text(context.l10n.sprintEnable),
            value: _values['enabled'] as bool,
            onChanged: (v) => setState(() => _values['enabled'] = v),
          ),
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(
              context.l10n.examDateLabel(
                _values['examDate'] as String? ?? context.l10n.chooseDate,
              ),
            ),
          ),
          ClassicSelect<String>(
            label: context.l10n.studyWordList,
            value: widget.books.any((b) => b.id == _values['bookId'])
                ? _values['bookId'] as String
                : (widget.books.isEmpty ? '' : widget.books.first.id),
            options: <ClassicOption<String>>[
              if (widget.books.isEmpty)
                ClassicOption<String>(
                  value: '',
                  label: context.l10n.noWordsYet,
                ),
              for (final book in widget.books)
                ClassicOption<String>(value: book.id, label: book.name),
            ],
            onChanged: widget.books.isEmpty
                ? null
                : (String v) => setState(() => _values['bookId'] = v),
          ),
          AppSpacing.h12,
          TextField(
            controller: _size,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: context.l10n.roundSizeRange),
          ),
          for (final option in <String, String>{
            'prioritizeHard': context.l10n.prioritizeHard,
            'prioritizeRecent': context.l10n.prioritizeRecent,
            'prioritizeUnmastered': context.l10n.prioritizeUnmastered,
            'includeUnlearned': context.l10n.includeUnlearned,
            'allowOverReviewLimit': context.l10n.allowOverReviewLimit,
          }.entries)
            SwitchListTile(
              title: Text(option.value),
              value: _values[option.key] as bool,
              onChanged: (v) => setState(() => _values[option.key] = v),
            ),
          Text(context.l10n.sprintDialogNote),
          if (_error != null)
            Text(
              describeAppError(context.l10n, _error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.commonCancel),
      ),
      ElevatedButton(
        onPressed: () {
          try {
            final plan = SprintPlan.fromJson({
              ..._values,
              'roundSize': int.tryParse(_size.text),
            });
            Navigator.pop(context, plan);
          } on AppError catch (error) {
            setState(() => _error = error.code);
          }
        },
        child: Text(context.l10n.commonSave),
      ),
    ],
  );
}
