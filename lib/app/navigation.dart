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

ShellLayout layoutFor({
  required double width,
  required TargetPlatform platform,
}) {
  final bool desktopPlatform = switch (platform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };
  if (desktopPlatform) {
    if (width >= AppDimens.desktopBreakpoint) return ShellLayout.rail;
    // A narrow macOS window keeps a (compact) side rail instead of dropping to
    // a phone-style bottom bar: the pointer-driven workflow is unchanged.
    return ShellLayout.compactRail;
  }
  // Tablets in landscape get the rail; phones keep the classic bottom bar.
  if (width >= AppDimens.desktopBreakpoint) return ShellLayout.rail;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeAutoSync(start: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    _dueTimer?.cancel();
    _duePlanTimer?.cancel();
    _dueGeneration++;
    _databaseChanges?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDailyData();
      _scheduleDueRefresh();
      _maybeAutoSync(start: false);
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

  void _refreshDailyData() {
    if (!mounted) return;
    ref.invalidate(todayProgressProvider);
    ref.invalidate(statisticsProvider);
    ref.invalidate(bookSummariesProvider);
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
        final report = await ref.read(syncCoordinatorProvider).autoSync();
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
      _lazy(0, DashboardPage(onOpenBookTab: () => _select(1))),
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
/// [Semantics]) because `BottomNavigationBar` cannot satisfy all of the phase-2
/// requirements at once:
///  * every item gets exactly the same width (`Expanded`) and the icon/label
///    box has a fixed height, so switching tabs cannot shift or scale anything;
///  * each item is wrapped in its own clipped [Material], so an InkSplash can
///    only paint inside that item — this is what removes the oversized grey
///    circle (and the ripple that appeared to belong to a neighbouring item);
///  * hover, focus, pressed and selected are four *separate* visual states;
///  * tapping never leaves a permanent M3 "pill" behind: the selection is a
///    colour/weight change only.
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
        theme.bottomNavigationBarTheme.unselectedItemColor ?? Colors.grey;
    final Color color = selected ? activeColor : inactiveColor;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.navigationRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.navigationRadius),
          ),
          splashFactory: InkRipple.splashFactory,
          canRequestFocus: true,
          // Four distinct feedbacks: hover (pointer), focus (keyboard),
          // highlight (pressed) and the persistent selected state.
          hoverColor: activeColor.withValues(alpha: 0.06),
          focusColor: activeColor.withValues(alpha: 0.14),
          highlightColor: activeColor.withValues(alpha: 0.10),
          splashColor: activeColor.withValues(alpha: 0.16),
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: color),
            duration: const Duration(milliseconds: 210),
            curve: Curves.easeInOut,
            builder: (context, animatedColor, _) => Tooltip(
              message: destination.label,
              waitDuration: const Duration(milliseconds: 700),
              child: Column(
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
              ? theme.colorScheme.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.radius),
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
