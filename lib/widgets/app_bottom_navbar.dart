import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/main_screen.dart';
import '../utils/app_constants.dart';

class AppNavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final int targetIndex;

  const AppNavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.targetIndex,
  });
}

class AppBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final List<AppNavItem>? items;

  const AppBottomNavbar({
    super.key,
    required this.currentIndex,
    this.onTap,
    this.items,
  });

  static const List<AppNavItem> defaultItems = [
    AppNavItem(
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
      label: 'Home',
      targetIndex: 0,
    ),
    AppNavItem(
      activeIcon: Icons.receipt_long_rounded,
      inactiveIcon: Icons.receipt_long_outlined,
      label: 'Token',
      targetIndex: 1,
    ),
    AppNavItem(
      activeIcon: Icons.people_rounded,
      inactiveIcon: Icons.people_outline_rounded,
      label: 'Customers',
      targetIndex: 2,
    ),
    AppNavItem(
      activeIcon: Icons.bar_chart_rounded,
      inactiveIcon: Icons.bar_chart_outlined,
      label: 'Analytics',
      targetIndex: 3,
    ),
    AppNavItem(
      activeIcon: Icons.settings_rounded,
      inactiveIcon: Icons.settings_outlined,
      label: 'Settings',
      targetIndex: 4,
    ),
  ];

  void _handleTap(BuildContext context, int index, int targetIndex) {
    if (onTap != null) {
      onTap!(index);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => MainScreen(initialIndex: targetIndex),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final navList = items ?? defaultItems;

    return Container(
      decoration: const BoxDecoration(
        color: StitchColors.background,
        border: Border(top: BorderSide(color: StitchColors.border, width: 1.0)),
      ),
      height: 56,
      child: Row(
        children: List.generate(navList.length, (index) {
          final item = navList[index];
          final isSelected = currentIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () => _handleTap(context, index, item.targetIndex),
              splashColor: StitchColors.primary.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 4),
                    color: isSelected ? StitchColors.primary : Colors.transparent,
                  ),
                  Icon(
                    isSelected ? item.activeIcon : item.inactiveIcon,
                    color: isSelected ? StitchColors.primary : StitchColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? StitchColors.primary : StitchColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
