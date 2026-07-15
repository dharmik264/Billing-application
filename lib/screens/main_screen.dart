import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_screen.dart';
import 'token_generation_screen.dart';
import 'item_management_screen.dart';
import 'analytics_reports_screen.dart';
import 'settings_screen.dart';
import 'customer_management_screen.dart';
import '../services/restaurant_api.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  static final ValueNotifier<bool> hideNavbar = ValueNotifier(false);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();

  bool _isLoading = true;
  final List<Widget> _screens = [];
  final List<Map<String, dynamic>> _navItems = [];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final permString = prefs.getString('permissions');
    Map<String, dynamic> perms = {};
    if (permString != null && permString.isNotEmpty) {
      perms = jsonDecode(permString);
    }

    _screens.add(DashboardScreen(key: _dashboardKey));
    _navItems.add({'icon': Icons.home_rounded, 'inactive': Icons.home_outlined, 'label': 'Home'});

    if (perms['billing'] ?? true) {
      _screens.add(const TokenGenerationScreen());
      _navItems.add({'icon': Icons.receipt_long_rounded, 'inactive': Icons.receipt_long_outlined, 'label': 'Token'});
    }
    if (perms['customers'] ?? true) {
      _screens.add(const CustomerManagementScreen());
      _navItems.add({'icon': Icons.people_rounded, 'inactive': Icons.people_outline_rounded, 'label': 'Customers'});
    }
    if (perms['inventory'] ?? true) {
      _screens.add(const ItemManagementScreen());
      _navItems.add({'icon': Icons.inventory_2_rounded, 'inactive': Icons.inventory_2_outlined, 'label': 'Items'});
    }
    if (perms['reports'] ?? true) {
      _screens.add(const AnalyticsReportsScreen());
      _navItems.add({'icon': Icons.bar_chart_rounded, 'inactive': Icons.bar_chart_outlined, 'label': 'Analytics'});
    }
    
    // Always show settings
    _screens.add(const SettingsScreen());
    _navItems.add({'icon': Icons.settings_rounded, 'inactive': Icons.settings_outlined, 'label': 'Settings'});

    setState(() {
      _isLoading = false;
    });
  }

  void _onTabTapped(int index) async {
    int tokenIndex = _navItems.indexWhere((nav) => nav['label'] == 'Token');
    if (index == tokenIndex) {
      try {
        final items = await RestaurantApi.instance.fetchItems();
        if (items.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No items available. Please add an item first, then create a bill.'),
                backgroundColor: Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      } catch (e) {
        // Allow navigation if API call fails
      }
    }

    if (index == 0 && _currentIndex != 0) {
      _dashboardKey.currentState?.refreshData();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
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
              ...List.generate(_navItems.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _desktopNavItem(i, _navItems[i]['icon'], _navItems[i]['inactive'], _navItems[i]['label']),
                );
              }),
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
              size: isSelected ? 30 : 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
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
        ValueListenableBuilder<bool>(
          valueListenable: MainScreen.hideNavbar,
          builder: (context, hide, child) {
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: 16,
              right: 16,
              bottom: hide ? -140 : 24,
              child: _buildUnifiedNavbar(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUnifiedNavbar() {
    List<Map<String, dynamic>> regularNavs = [];
    int tokenIndex = -1;
    for (int i = 0; i < _navItems.length; i++) {
      if (_navItems[i]['label'] == 'Token') {
        tokenIndex = i;
      } else {
        regularNavs.add({'index': i, ..._navItems[i]});
      }
    }
    int half = (regularNavs.length / 2).ceil();
    List<Map<String, dynamic>> leftNavs = regularNavs.sublist(0, half);
    List<Map<String, dynamic>> rightNavs = regularNavs.sublist(half);

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: leftNavs.map((nav) => _mobileNavItem(nav['index'], nav['icon'], nav['inactive'], nav['label'])).toList(),
          ),
          if (tokenIndex != -1)
            GestureDetector(
              onTap: () => _onTabTapped(tokenIndex),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: rightNavs.map((nav) => _mobileNavItem(nav['index'], nav['icon'], nav['inactive'], nav['label'])).toList(),
          ),
        ],
      ),
    );
  }

  Widget _mobileNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: isSelected ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12) : const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
