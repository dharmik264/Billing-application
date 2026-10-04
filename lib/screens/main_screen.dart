import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_screen.dart';
import 'token_generation_screen.dart';
import 'item_management_screen.dart';
import 'analytics_reports_screen.dart';
import 'settings_screen.dart';
import 'customer_management_screen.dart';
import '../services/restaurant_api.dart';
import '../services/printer_service.dart';

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
    PrinterService.instance.attemptAutoConnect();
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

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Exit Application',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF0F172A)),
        ),
        content: Text(
          'Are you sure you want to exit the application?',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Exit',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
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
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOutQuint,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuint)),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: _screens[_currentIndex],
              ),
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
    return ValueListenableBuilder<bool>(
      valueListenable: MainScreen.hideNavbar,
      builder: (context, hide, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_currentIndex),
              child: _screens[_currentIndex],
            ),
          ),
          bottomNavigationBar: hide
              ? null
              : _buildFlatNavbar(),
        );
      },
    );
  }

  Widget _buildFlatNavbar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      height: 60,
      child: Row(
        children: _navItems.map((nav) {
          final index = _navItems.indexOf(nav);
          return _flatNavItem(index, nav['icon'], nav['inactive'], nav['label']);
        }).toList(),
      ),
    );
  }

  Widget _flatNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = _currentIndex == index;
    const indigo = Color(0xFF4F46E5);
    const slate400 = Color(0xFF94A3B8);

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        splashColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Thin indigo indicator on top for selected
            Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 4),
              color: isSelected ? indigo : Colors.transparent,
            ),
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? indigo : slate400,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? indigo : slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
