import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'dashboard_screen.dart';
import 'token_generation_screen.dart';
import 'item_management_screen.dart';
import 'analytics_reports_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(key: _dashboardKey),
      const TokenGenerationScreen(),
      const ItemManagementScreen(),
      const AnalyticsReportsScreen(),
      const SettingsScreen(),
    ];
  }

  void _onTabTapped(int index) {
    if (index == 0 && _currentIndex != 0) {
      _dashboardKey.currentState?.refreshData();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50 background
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Container(
          width: 100,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _desktopNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              const SizedBox(height: 16),
              _desktopNavItem(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Token'),
              const SizedBox(height: 16),
              _desktopNavItem(2, Icons.inventory_2_rounded, Icons.inventory_2_outlined, 'Items'),
              const SizedBox(height: 16),
              _desktopNavItem(3, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Analytics'),
              const SizedBox(height: 16),
              _desktopNavItem(4, Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              bottomLeft: Radius.circular(32),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _screens[_currentIndex],
            ),
          ),
        ),
      ],
    );
  }

  Widget _desktopNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFAAAAAA),
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFAAAAAA),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _screens[_currentIndex],
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _mobileNavItem(0, Icons.home_rounded, Icons.home_outlined),
                _mobileNavItem(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined),
                _mobileNavItem(2, Icons.inventory_2_rounded, Icons.inventory_2_outlined),
                _mobileNavItem(3, Icons.bar_chart_rounded, Icons.bar_chart_outlined),
                _mobileNavItem(4, Icons.settings_rounded, Icons.settings_outlined),
              ],
            ),
          ).animate().slideY(begin: 1, duration: 600.ms, curve: Curves.easeOutQuart),
        ),
      ],
    );
  }

  Widget _mobileNavItem(int index, IconData activeIcon, IconData inactiveIcon) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSelected ? activeIcon : inactiveIcon,
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          size: 26,
        ),
      ),
    );
  }
}
