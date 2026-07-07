import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'super_admin_dashboard_screen.dart';

class SuperAdminMainScreen extends StatefulWidget {
  const SuperAdminMainScreen({super.key});

  @override
  State<SuperAdminMainScreen> createState() => _SuperAdminMainScreenState();
}

class _SuperAdminMainScreenState extends State<SuperAdminMainScreen> {
  int _currentIndex = 0;
  final GlobalKey<SuperAdminDashboardScreenState> _dashboardKey =
      GlobalKey<SuperAdminDashboardScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      SuperAdminDashboardScreen(key: _dashboardKey),
      _placeholderTab('System Logs', Icons.receipt_long_rounded),
      _placeholderTab('User Management', Icons.bolt_rounded),
      _placeholderTab('Statistics', Icons.pie_chart_rounded),
      _placeholderTab('Admin Profile', Icons.person_rounded),
    ];
  }

  Widget _placeholderTab(String title, IconData icon) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 48, color: const Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
            const SizedBox(height: 6),
            Text('Coming Soon', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    if (index == 0 && _currentIndex != 0) {
      _dashboardKey.currentState?.refreshData();
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return _buildDesktopLayout();
          }
          return _buildMobileLayout();
        },
      ),
    );
  }

  // ── Desktop Layout ─────────────────────────────────────────

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Container(
          width: 100,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _desktopNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              const SizedBox(height: 16),
              _desktopNavItem(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Logs'),
              const SizedBox(height: 16),
              _desktopNavItem(2, Icons.bolt_rounded, Icons.bolt_outlined, 'Users'),
              const SizedBox(height: 16),
              _desktopNavItem(3, Icons.pie_chart_rounded, Icons.pie_chart_outline_rounded, 'Stats'),
              const SizedBox(height: 16),
              _desktopNavItem(4, Icons.person_rounded, Icons.person_outline, 'Admin'),
            ],
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), bottomLeft: Radius.circular(32)),
            child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _screens[_currentIndex]),
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
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : inactiveIcon, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFAAAAAA), size: 28),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFAAAAAA))),
          ],
        ),
      ),
    );
  }

  // ── Mobile Layout ──────────────────────────────────────────

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _screens[_currentIndex]),
        Positioned(
          left: 24, right: 24, bottom: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _mobileNavItem(0, Icons.home_rounded, Icons.home_outlined),
                _mobileNavItem(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined),
                _mobileNavItem(2, Icons.bolt_rounded, Icons.bolt_outlined),
                _mobileNavItem(3, Icons.pie_chart_rounded, Icons.pie_chart_outline_rounded),
                _mobileNavItem(4, Icons.person_rounded, Icons.person_outline),
              ],
            ),
          ),
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
        child: Icon(isSelected ? activeIcon : inactiveIcon, color: isSelected ? Colors.white : const Color(0xFF94A3B8), size: 26),
      ),
    );
  }
}
