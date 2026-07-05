import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The persistent scaffold that hosts the bottom navigation bar and the
/// currently-selected tab's content.
///
/// [navigationShell] is handed to us by [StatefulShellRoute] (see app_router).
/// It knows which branch (tab) is active and how to switch between them, while
/// keeping each tab's own navigation stack and scroll position alive.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    // Switch to the tapped tab. Re-tapping the current tab resets it to that
    // tab's root route — the behavior users expect from a bottom nav bar.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell, // renders the active tab
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
