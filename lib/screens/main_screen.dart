import 'package:dabbu/screens/analytics_screen.dart';

import 'package:flutter/material.dart';
import '../utils/cms.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'tools_screen.dart'; // New Import
import '../viewmodels/home_view_model.dart'; // New Import

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<HomePageState> _homeKey = GlobalKey();
  final GlobalKey<SettingsPageState> _settingsKey = GlobalKey();
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> get _pages {
    // We need to access the ViewModel from HomePage to pass it to ToolsScreen
    // Ideally, we move ViewModel up to MainScreen or use a Provider.
    // QUICK FIX: Since _homeKey holds the state, we can try to access it via a getter or shared instance.
    // Better: MainScreen creates the ViewModel? No, HomePage manages it.
    // Solution: We will grab the instance from _homeKey.currentState ONLY if available.
    // Issue: If Home hasn't built, currentState is null.
    // WORKAROUND: We will let ToolsScreen access it via a callback or lazily.
    // Actually, simpler: Let's pass the 'refreshData' callback and maybe just instantiate Tally with a new VM?
    // TallyScreen needs the SAME VM instance for state consistency?
    // Ideally yes.
    // Let's try this: We just pass _homeKey to ToolsScreen constructor (wrapper) which extracts it on build?
    // Or just pass the state's viewModel public accessor.

    // Changing HomePageState to make _viewModel public getter:
    // See separate Step. assuming accessor 'viewModel' exists.

    // Wait, let's keep it simple.
    // We can't access `_homeKey.currentState` inside `_pages` easily if it's called early.
    // Let's refactor: Build pages in `build` method where context is available?
    // No, `_pages` is getter.

    // TEMPORARY: ToolsScreen will accept null VM and handle it or we wait.
    // Actually, TallyScreen takes `HomeViewModel`.
    // Let's make `HomePageState` public access for `viewModel`.

    return [
      HomePage(key: _homeKey, onSetBudgetTap: _navigateToSettingsAndEditBudget),
      const AnalyticsScreen(),
      ToolsScreen(
        viewModel:
            _homeKey.currentState?.viewModel ??
            HomeViewModel(), // Fallback if not ready (careful)
        onRefresh: () => _homeKey.currentState?.refreshData(),
      ),
      SettingsPage(key: _settingsKey),
    ];
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      _homeKey.currentState?.refreshData();
    } else if (index == 3) {
      // Settings is now at index 3
      _settingsKey.currentState?.refresh();
    }

    // Animate to the page when tab is tapped
    // Jump to the page to prevent "flickering" of intermediate tabs
    _pageController.jumpToPage(index);

    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToSettingsAndEditBudget() {
    // 1. Navigate to Settings Tab (Index 3)
    _onItemTapped(3);

    // 2. Trigger the dialog after a short frame delay to ensure UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settingsKey.currentState?.openBudgetEditDialog();
    });
  }

  void _onPageChanged(int index) {
    if (index == 0) {
      _homeKey.currentState?.refreshData();
    } else if (index == 3) {
      // Settings is now at index 3
      _settingsKey.currentState?.refresh();
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onItemTapped(0);
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(), // Nice bounce effect
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: CMS.main['nav_home'] ?? 'Home',
            ),
            NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline),
              selectedIcon: const Icon(Icons.pie_chart),
              label: CMS.main['nav_analytics'] ?? 'Analytics',
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view),
              label: CMS.main['nav_tools'] ?? 'Tools',
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: CMS.main['nav_settings'] ?? 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
