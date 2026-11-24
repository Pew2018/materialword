import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dashboard/dashboard_page.dart';
import '../features/dictionary/dictionary_page.dart';
import '../features/settings/settings_page.dart';
import '../features/statistics/statistics_page.dart';
import '../features/word_management/quick_add_page.dart';
import '../features/wordbooks/wordbooks_page.dart';
import 'theme.dart';

/// One entry in the bottom bar / desktop side navigation.
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

/// Application frame: an [AppBar] plus either a bottom navigation bar (phones)
/// or a permanent side navigation (macOS / tablets). All screens share the same
/// Dart code, only the surrounding chrome changes.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  final FocusNode _searchFocus = FocusNode(debugLabel: 'dictionary-search');

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  bool get _isEditingText {
    final BuildContext? context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText;
  }

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
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final bool isDesktop = media.size.width >= AppDimens.desktopBreakpoint;

    final List<Widget> pages = <Widget>[
      DashboardPage(onOpenBookTab: () => _select(1)),
      const WordBooksPage(),
      DictionaryPage(searchFocusNode: _searchFocus),
      const StatisticsPage(),
      const SettingsPage(),
    ];

    final Widget body = CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          if (!_isEditingText) _focusSearch();
        },
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
          if (!_isEditingText) _quickAdd();
        },
      },
      child: Focus(autofocus: true, child: pages[_index]),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(appDestinations[_index].label),
        actions: <Widget>[
          if (isDesktop)
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
        ],
      ),
      body: SafeArea(
        top: false,
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SideNavigation(index: _index, onSelect: _select),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _index,
              onTap: _select,
              items: <BottomNavigationBarItem>[
                for (final AppDestination destination in appDestinations)
                  BottomNavigationBarItem(
                    icon: Icon(destination.icon),
                    activeIcon: Icon(destination.activeIcon),
                    label: destination.label,
                  ),
              ],
            ),
      floatingActionButton: _index == 0 && !isDesktop
          ? FloatingActionButton(
              onPressed: _quickAdd,
              tooltip: '快速添加单词',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: AppDimens.navRailWidth,
      child: Material(
        color: theme.cardColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.menu_book,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
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
            ),
            const Divider(height: 1),
            AppSpacing.h8,
            for (int i = 0; i < appDestinations.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: ListTile(
                  dense: true,
                  selected: i == index,
                  selectedTileColor: theme.colorScheme.primary.withValues(
                    alpha: 0.10,
                  ),
                  selectedColor: theme.colorScheme.primary,
                  leading: Icon(
                    i == index
                        ? appDestinations[i].activeIcon
                        : appDestinations[i].icon,
                    size: AppDimens.iconSize,
                  ),
                  title: Text(appDestinations[i].label),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radius),
                  ),
                  onTap: () => onSelect(i),
                ),
              ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('离线可用 · 本地优先', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
