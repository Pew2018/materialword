import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
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
  String? _error;
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
                _error = '读取冲刺计划失败，请重试';
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
          _error = '读取冲刺计划失败，请重试';
        });
      }
    }
  }

  Future<void> _configure() async {
    if (_busy) return;
    if (_books.isEmpty) {
      showMessage(context, '请先创建或导入词书');
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
      if (mounted) showMessage(context, '保存冲刺计划失败，请重试', error: true);
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
        showMessage(context, '当前没有可安排的冲刺任务，请检查计划与今日额度');
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
      if (mounted) showMessage(context, '准备冲刺任务失败，请重试', error: true);
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
        title: const Text('考前冲刺'),
        actions: [
          IconButton(
            tooltip: '设置冲刺计划',
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
                    ErrorBanner(message: _error!, onRetry: _load),
                  if (_busy) const LinearProgressIndicator(),
                  Text(
                    _plan.examDate == null
                        ? '设置考试日期，建立独立冲刺计划'
                        : days! < 0
                        ? '考试日期已过 ${-days} 天'
                        : days == 0
                        ? '今天考试'
                        : '距离考试 $days 天',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  AppSpacing.h8,
                  Text('目标词书：${book?.name ?? '未选择或已删除'}'),
                  if (!_plan.enabled)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('冲刺未启用；普通学习计划保持原样。'),
                    ),
                  if (_plan.bookId != null && view?.bookAvailable == false)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('目标词书不可用，请重新选择；不会自动改成全部词书。'),
                    ),
                  if (view != null) ...[
                    AppSpacing.h24,
                    Row(
                      children: [
                        Expanded(
                          child: StatBlock(
                            value: '${view.unlearned}',
                            label: '剩余未学',
                          ),
                        ),
                        Expanded(
                          child: StatBlock(value: '${view.hard}', label: '困难词'),
                        ),
                        Expanded(
                          child: StatBlock(
                            value: '${view.recentMistakes}',
                            label: '近 7 天错误词',
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.h24,
                    Text(
                      '新一轮可安排 ${view.wordIds.length} 个 / 每轮 ${_plan.roundSize} 个',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '范围内可选 ${view.eligible} 个 · 今日普通复习余量 ${view.reviewAllowance} 个',
                    ),
                    if (!_plan.includeUnlearned &&
                        view.eligible == 0 &&
                        view.unlearned > 0)
                      const Text('当前只剩未学习词，可在计划中允许包含未学习词。'),
                    if (!_plan.allowOverReviewLimit &&
                        view.reviewAllowance == 0)
                      const Text('今日复习额度已用完；需要继续时可在计划中明确允许超限。'),
                  ],
                  AppSpacing.h16,
                  const Text(
                    '优先困难和近期错误，同时保留部分名额覆盖其他单词，避免偶发失误一直占满任务。真实作答保留，短期答对不会把已有长间隔再次推远。',
                  ),
                  AppSpacing.h24,
                  ElevatedButton.icon(
                    onPressed: _busy || view == null || view.wordIds.isEmpty
                        ? null
                        : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(continuing ? '继续本轮冲刺' : '开始本轮冲刺'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _configure,
                    child: const Text('设置冲刺计划'),
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
                      child: const Text('退出冲刺，保留普通计划'),
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
  String? _error;
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
    title: const Text('冲刺计划'),
    scrollable: true,
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('启用冲刺'),
            value: _values['enabled'] as bool,
            onChanged: (v) => setState(() => _values['enabled'] = v),
          ),
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text('考试日期：${_values['examDate'] ?? '请选择'}'),
          ),
          ClassicSelect<String>(
            label: '目标词书',
            value: widget.books.any((b) => b.id == _values['bookId'])
                ? _values['bookId'] as String
                : (widget.books.isEmpty ? '' : widget.books.first.id),
            options: <ClassicOption<String>>[
              if (widget.books.isEmpty)
                const ClassicOption<String>(value: '', label: '还没有词书'),
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
            decoration: const InputDecoration(labelText: '每轮单词数量（1–500）'),
          ),
          for (final option in const {
            'prioritizeHard': '优先困难词',
            'prioritizeRecent': '优先近期错误词',
            'prioritizeUnmastered': '优先未掌握词',
            'includeUnlearned': '包括未学习词',
            'allowOverReviewLimit': '允许超过普通每日复习上限',
          }.entries)
            SwitchListTile(
              title: Text(option.value),
              value: _values[option.key] as bool,
              onChanged: (v) => setState(() => _values[option.key] = v),
            ),
          const Text('冲刺是独立练习；关闭超限时，按当前已知今日复习余量安排。修改计划会重新安排任务，已作答历史会保留。'),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      ElevatedButton(
        onPressed: () {
          try {
            final plan = SprintPlan.fromJson({
              ..._values,
              'roundSize': int.tryParse(_size.text),
            });
            Navigator.pop(context, plan);
          } on FormatException catch (e) {
            setState(() => _error = e.message);
          }
        },
        child: const Text('保存计划'),
      ),
    ],
  );
}
