import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../widgets/common.dart';
import 'browse_screen.dart';
import 'saved_screen.dart';
import 'search_screen.dart';
import 'today_screen.dart';

/// Root screen with bottom navigation. Tabs live in an [IndexedStack] so
/// scroll positions and search text survive tab switches.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const int todayTab = 0, searchTab = 2;
  int _index = todayTab;

  void _select(int i) {
    if (i == _index) return;
    // Dismiss the keyboard when leaving the search tab.
    if (_index == searchTab) FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _index = i);
    AppScope.of(context).analytics.screen(_tabNames[i]);
  }

  static const _tabNames = ['tab_today', 'tab_browse', 'tab_search', 'tab_saved'];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back from any tab returns to "Today" before leaving the app.
      canPop: _index == todayTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(todayTab);
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  TodayScreen(onOpenSearch: () => _select(searchTab)),
                  const BrowseScreen(),
                  SearchScreen(active: _index == searchTab),
                  const SavedScreen(),
                ],
              ),
            ),
            const StorageWarningBanner(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined),
              selectedIcon: Icon(Icons.wb_sunny),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.sort_by_alpha_outlined),
              selectedIcon: Icon(Icons.sort_by_alpha),
              label: 'Browse',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Saved',
            ),
          ],
        ),
      ),
    );
  }
}
