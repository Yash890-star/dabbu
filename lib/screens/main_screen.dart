import 'package:dabbu/screens/analytics_screen.dart';
import 'package:dabbu/screens/calendar_screen.dart';
import 'package:flutter/material.dart';
import '../utils/cms.dart';
import 'home_page.dart';
import 'settings_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<HomePageState> _homeKey = GlobalKey();

  List<Widget> get _pages => [
    HomePage(key: _homeKey),
    const AnalyticsScreen(),
    const CalendarScreen(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    if (index == 0) {
      _homeKey.currentState?.refreshData();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _onItemTapped(0);
      },
      child: Scaffold(
        body: IndexedStack(
          // Keeps state alive when switching tabs
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: CMS.main['nav_home']!,
            ),
            NavigationDestination(
              icon: const Icon(Icons.pie_chart_outline),
              selectedIcon: const Icon(Icons.pie_chart),
              label: CMS.main['nav_analytics']!,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: CMS.main['nav_calendar']!,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: CMS.main['nav_settings']!,
            ),
          ],
        ),
      ),
    );
  }
}
