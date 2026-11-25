import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/dashboard_page.dart';
import '../features/dictionary/dictionary_page.dart';
import '../features/settings/settings_page.dart';
import '../features/statistics/statistics_page.dart';
import '../features/word_management/quick_add_page.dart';
import '../features/word_management/word_management_page.dart';
import '../features/wordbooks/wordbooks_page.dart';
import '../services/diagnostics_service.dart';
import '../services/backup_manager.dart';
import 'providers.dart';
import 'theme.dart';

/// One entry in the bottom bar / side navigation.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const List<AppDestination> appDestinations = <AppDestination>[
  AppDestination(
    label: '今日',
    icon: Icons.today_outlined,
    activeIcon: Icons.today,
  ),
  AppDestination(
    label: '词书',
    icon: Icons.library_books_outlined,
    activeIcon: Icons.library_books,
  ),
  AppDestination(label: '词典', icon: Icons.search, activeIcon: Icons.search),
  AppDestination(
    label: '统计',
    icon: Icons.insert_chart_outlined,
    activeIcon: Icons.insert_chart,
  ),
  AppDestination(
    label: '设置',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
  ),
];

/// Which navigation chrome the current window should use.
enum ShellLayout { bottomBar, compactRail, rail }

/// Picks the navigation chrome from the *window width*, not the platform.
///
/// A narrow macOS window must behave like a phone: keeping an icon rail in a
/// 500dp window cost ~76dp of content width and produced wrapped numbers and
/// squeezed buttons. [platform] is kept in the signature because callers (and
/// tests) already have it, but it no longer decides the layout.
ShellLayout layoutFor({
  required double width,
  required TargetPlatform platform,
}) {
  if (width >= AppDimens.desktopBreakpoint) return ShellLayout.rail;
  if (width >= AppDimens.railCollapseBreakpoint) {
    return ShellLayout.compactRail;
  }
  return ShellLayout.bottomBar;
}

/// Application frame: an [AppBar] plus the platform-appropriate navigation.
///
/// First-level pages live in a lazily populated [IndexedStack]: scrolling,
/// search text and expanded sections survive tab switches, but a page is not
/// mounted (and therefore runs no database query or dictionary init) until the
/// user actually visits it.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _index = 0;
  final Set<int> _built = <int>{0};
  final FocusNode _searchFocus = FocusNode(debugLabel: 'dictionary-search');
  Timer? _dayTimer;
  Timer? _dueTimer;
  Timer? _duePlanTimer;
  StreamSubscription<dynamic>? _databaseChanges;
  int _dueGeneration = 0;
  bool _autoSyncStarted = false;
  Timer? _autoBackupTimer;
  bool _autoBackupRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(autoSyncServiceProvider).start();
    _scheduleDayBoundary();
    _scheduleDueRefresh();
    _databaseChanges = ref.read(databaseProvider).tableUpdates().listen((
      updates,
    ) {
      if (!updates.any(
        (u) => <String>{
          'words',
          'learning_states',
          'word_books',
          'word_book_entries',
          'study_settings',
        }.contains(u.table),
      )) {
        return;
      }
      _duePlanTimer?.cancel();
      _duePlanTimer = Timer(const Duration(milliseconds: 250), () {
        _refreshDailyData();
        _scheduleDueRefresh();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoSync(start: true);
      _runAutoBackup(reason: 'start');
    });
    _scheduleAutoBackupChecks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    _dueTimer?.cancel();
    _duePlanTimer?.cancel();
    _dueGeneration++;
    _autoBackupTimer?.cancel();
    _databaseChanges?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Automatic local backups are checked at start-up, on resume and every half
  /// hour while the app stays open. The manager decides whether a backup is due
  /// (interval + data actually changed); this timer only asks.
  void _scheduleAutoBackupChecks() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _runAutoBackup(reason: 'timer'),
    );
  }

  Future<void> _runAutoBackup({required String reason}) async {
    if (_autoBackupRunning || !mounted) return;
    _autoBackupRunning = true;
    try {
      await ref.read(backupManagerProvider).cleanupTempFiles();
      final AutoBackupResult result = await ref
          .read(backupManagerProvider)
          .autoBackupIfDue();
      if (result.created) {
        DiagnosticsService.instance.log(
          'backup',
          'automatic backup created ($reason)',
        );
      } else if (result.error != null) {
        // Never surfaced as a modal: a failed background backup must not
        // interrupt studying. The backup page shows the last successful time.
        DiagnosticsService.instance.log(
          'backup',
          'automatic backup failed ($reason): ${result.error}',
          error: true,
        );
      }
    } catch (_) {
      // Housekeeping failures are logged, never thrown into the UI.
    } finally {
      _autoBackupRunning = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref
        .read(autoSyncServiceProvider)
        .setForeground(state == AppLifecycleState.resumed);
    if (state != AppLifecycleState.resumed) {
      ref.read(ttsServiceProvider).stop();
      // The OS may kill a backgrounded process at any time, so anything still
      // buffered in memory is written now rather than never.
      unawaited(DiagnosticsService.instance.flushToDisk());
    }
    if (state == AppLifecycleState.resumed) {
      _refreshDailyData();
      _scheduleDueRefresh();
      _maybeAutoSync(start: false);
      _runAutoBackup(reason: 'resume');
    }
  }

  /// Recomputes "today" after midnight and whenever the app comes back to the
  /// foreground. Without this a long-running window kept yesterday's queue.
  void _scheduleDayBoundary() {
    _dayTimer?.cancel();
    final DateTime now = DateTime.now();
    final DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 2),
      () {
        _refreshDailyData();
        _scheduleDayBoundary();
      },
    );
  }

  Future<void> _scheduleDueRefresh() async {
    if (!mounted) return;
    final generation = ++_dueGeneration;
    _dueTimer?.cancel();
    try {
      final now = ref.read(clockProvider).now();
      final next = await ref.read(studyRepositoryProvider).nextDueAfter(now);
      if (!mounted || generation != _dueGeneration) return;
      // An hourly ceiling also rechecks timezone/system clock changes.
      final millis = next == null
          ? 3600000
          : next.difference(now).inMilliseconds + 100;
      _dueTimer = Timer(Duration(milliseconds: millis.clamp(50, 3600000)), () {
        _refreshDailyData();
        _scheduleDueRefresh();
      });
    } catch (_) {
      // Resume and subsequent database writes schedule a new attempt.
    }
  }

  /// Refreshes only what the *visible* page shows.
  ///
  /// Every database write used to invalidate the statistics aggregate and the
  /// book summaries, so a background sync (or the 30-minute backup probe) could
  /// rebuild the statistics page and its chart while the user was scrolling
  /// settings. Hidden pages are refreshed when they are selected again instead.
  void _refreshDailyData() {
    if (!mounted) return;
    ref.invalidate(todayProgressProvider);
    ref.invalidate(pausedSessionProvider);
    if (_index == 3) ref.invalidate(statisticsProvider);
    if (_index == 0 || _index == 1 || _index == 4) {
      ref.invalidate(bookSummariesProvider);
    }
  }

  Future<void> _maybeAutoSync({required bool start}) async {
    if (!mounted) return;
    if (_autoSyncStarted && start) return;
    final Map<String, Object?>? config = await ref
        .read(settingsRepositoryProvider)
        .syncConfig();
    if (config == null || !mounted) return;
    final bool enabled = start
        ? config['autoOnStart'] == true
        : config['autoOnResume'] == true;
    if (!enabled) return;
    if (start) _autoSyncStarted = true;
    // Never block the UI: sync runs in the background and only invalidates the
    // data providers when it actually changed something.
    unawaited(() async {
      try {
        final report = await ref
            .read(syncCoordinatorProvider)
            .autoSync(trigger: start ? 'start' : 'resume');
        if (report != null && report.ok && report.merge != null) {
          _refreshDailyData();
        }
      } catch (_) {
        // Automatic sync failures are surfaced on the sync page, not as a
        // blocking dialog, and the app keeps working offline.
      }
    }());
  }

  void _select(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _index = index;
      _built.add(index);
    });
    // A page that was hidden while data changed recomputes once, now that it is
    // on screen. Values stay on screen while reloading (AsyncValue keeps the
    // previous data), so there is no loading flash.
    switch (index) {
      case 0:
        ref.invalidate(todayProgressProvider);
        ref.invalidate(pausedSessionProvider);
        ref.invalidate(bookSummariesProvider);
      case 1 || 4:
        ref.invalidate(bookSummariesProvider);
      case 3:
        ref.invalidate(statisticsProvider);
        ref.invalidate(bookSummariesProvider);
    }
  }

  bool get _isEditingText {
    final BuildContext? context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText;
  }

  bool get _hasModalRoute =>
      ModalRoute.of(context)?.isCurrent == false ||
      Navigator.of(context).canPop();

  void _focusSearch() {
    _select(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_searchFocus.context != null) _searchFocus.requestFocus();
    });
  }

  Future<void> _quickAdd() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const QuickAddPage(),
      ),
    );
    _refreshDailyData();
  }

  Future<void> _openWordManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const WordManagementPage(),
      ),
    );
    _refreshDailyData();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final ShellLayout layout = layoutFor(
      width: media.size.width,
      platform: Theme.of(context).platform,
    );
    final bool hasRail = layout != ShellLayout.bottomBar;

    final List<Widget> pages = <Widget>[
      _lazy(0, const DashboardPage()),
      _lazy(1, const WordBooksPage()),
      _lazy(2, DictionaryPage(searchFocusNode: _searchFocus)),
      _lazy(3, const StatisticsPage()),
      _lazy(4, const SettingsPage()),
    ];

    final Widget body = CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          if (!_isEditingText && !_hasModalRoute) _focusSearch();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          if (!_isEditingText && !_hasModalRoute) _focusSearch();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
          if (!_isEditingText && !_hasModalRoute) _quickAdd();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          if (!_isEditingText && !_hasModalRoute) _quickAdd();
        },
      },
      child: Focus(
        autofocus: true,
        child: IndexedStack(index: _index, children: pages),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(appDestinations[_index].label),
        actions: <Widget>[
          if (hasRail)
            IconButton(
              tooltip: '快速添加单词 (⌘N)',
              icon: const Icon(Icons.add),
              onPressed: _quickAdd,
            ),
          if (_index == 2)
            IconButton(
              tooltip: '搜索 (⌘F)',
              icon: const Icon(Icons.search),
              onPressed: _focusSearch,
            ),
          if (_index == 1 && hasRail)
            IconButton(
              tooltip: '全部词汇管理',
              icon: const Icon(Icons.table_rows_outlined),
              onPressed: _openWordManagement,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: hasRail
                  ? (layout == ShellLayout.compactRail
                        ? AppDimens.navRailCompactWidth
                        : AppDimens.navRailWidth)
                  : 0,
              child: hasRail
                  ? _SideNavigation(
                      index: _index,
                      compact: layout == ShellLayout.compactRail,
                      onSelect: _select,
                      onManageWords: _openWordManagement,
                    )
                  : null,
            ),
            SizedBox(
              width: hasRail ? 1 : 0,
              child: const VerticalDivider(width: 1),
            ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: hasRail
          ? null
          : ClassicBottomNavigationBar(currentIndex: _index, onTap: _select),
      floatingActionButton: _index == 0 && !hasRail
          ? FloatingActionButton(
              onPressed: _quickAdd,
              tooltip: '快速添加单词',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Mounts a first-level page only after its tab has been opened at least
  /// once. Keeps start-up cheap: five pages would otherwise fire five sets of
  /// database queries (and the dictionary provider) immediately.
  Widget _lazy(int index, Widget page) => ExcludeFocus(
    excluding: index != _index,
    child: _built.contains(index) ? page : const SizedBox.shrink(),
  );
}

/// Classic Material 1/2 bottom navigation bar.
///
/// Built on the official primitives ([Material], [InkWell], [Row], [Expanded],
/// [Semantics]) because `BottomNavigationBar` cannot satisfy all of the
/// requirements at once:
///  * every item is an equal-width rectangle with a fixed 56dp height, so
///    switching tabs cannot shift, scale or re-wrap anything;
///  * the selected destination is expressed **only** by the active icon, the
///    accent colour and a slightly heavier label — the background never gets a
///    persistent tint, pill or rounded container;
///  * the item's ink response is clipped by its own *rectangle* (no rounded
///    `customBorder`), so a tap produces the large classic Material ripple the
///    reference design shows, and nothing is left behind afterwards.
class ClassicBottomNavigationBar extends StatelessWidget {
  const ClassicBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = appDestinations,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppDestination> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.bottomNavigationBarTheme.backgroundColor ?? theme.cardColor,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDimens.bottomNavHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    key: ValueKey<String>('nav-${items[i].label}'),
                    destination: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color activeColor =
        theme.bottomNavigationBarTheme.selectedItemColor ??
        theme.colorScheme.primary;
    final Color inactiveColor =
        theme.bottomNavigationBarTheme.unselectedItemColor ??
        theme.textTheme.bodySmall?.color ??
        theme.disabledColor;
    final Color color = selected ? activeColor : inactiveColor;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      // Clipped by a plain rectangle: the splash may grow into a large circle
      // but it is cut off at the item edge, exactly like the classic bar.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          splashFactory: InkRipple.splashFactory,
          canRequestFocus: true,
          hoverColor: activeColor.withValues(alpha: 0.04),
          focusColor: activeColor.withValues(alpha: 0.10),
          highlightColor: activeColor.withValues(alpha: 0.08),
          splashColor: activeColor.withValues(alpha: 0.14),
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: color),
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            builder: (context, animatedColor, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Fixed 24dp icon box: the icon never grows or shrinks when
                // the item becomes selected.
                SizedBox(
                  height: AppDimens.iconSize,
                  width: AppDimens.iconSize,
                  child: Icon(
                    selected ? destination.activeIcon : destination.icon,
                    size: AppDimens.iconSize,
                    color: animatedColor,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 16,
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.1,
                      color: animatedColor,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.index,
    required this.onSelect,
    required this.onManageWords,
    this.compact = false,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onManageWords;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color active = theme.colorScheme.primary;
    return SizedBox(
      width: compact ? AppDimens.navRailCompactWidth : AppDimens.navRailWidth,
      child: Material(
        color: theme.cardColor,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.menu_book, size: 22, color: active),
                      AppSpacing.w8,
                      Expanded(
                        child: Text(
                          'MaterialWord',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppSpacing.h12,
              const Divider(height: 1),
              AppSpacing.h8,
              for (int i = 0; i < appDestinations.length; i++)
                _RailItem(
                  key: ValueKey<String>('nav-${appDestinations[i].label}'),
                  destination: appDestinations[i],
                  selected: i == index,
                  compact: compact,
                  onTap: () => onSelect(i),
                ),
              const Divider(height: 16, indent: 12, endIndent: 12),
              _RailItem(
                key: const ValueKey<String>('nav-词汇'),
                destination: const AppDestination(
                  label: '词汇',
                  icon: Icons.table_rows_outlined,
                  activeIcon: Icons.table_rows,
                ),
                selected: false,
                compact: compact,
                onTap: onManageWords,
              ),

              if (!compact)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('离线可用 · 本地优先', style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = selected
        ? theme.colorScheme.primary
        : theme.textTheme.bodySmall?.color ?? theme.disabledColor;
    final Widget content = Row(
      children: <Widget>[
        Icon(
          selected ? destination.activeIcon : destination.icon,
          size: AppDimens.iconSize,
          color: color,
        ),
        if (!compact) ...<Widget>[
          AppSpacing.w12,
          Expanded(
            child: Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Semantics(
        selected: selected,
        button: true,
        label: destination.label,
        excludeSemantics: true,
        child: Material(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: onTap,
            hoverColor: theme.colorScheme.primary.withValues(alpha: 0.06),
            focusColor: theme.colorScheme.primary.withValues(alpha: 0.14),
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.14),
            child: Tooltip(
              message: compact ? destination.label : '',
              waitDuration: const Duration(milliseconds: 600),
              child: SizedBox(
                height: AppDimens.listItemHeight - 8,
                child: compact
                    ? Center(child: content)
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: content,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
