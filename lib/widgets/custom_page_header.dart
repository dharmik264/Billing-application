import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0F172A), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
}

class FilterChipData {
  final String label;
  final String value;
  final IconData icon;

  FilterChipData({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class CustomSearchActionView extends StatelessWidget {
  final String? searchHint;
  final TextEditingController? searchController;
  final void Function(String)? onSearchChanged;
  final void Function()? onSearchClear;
  
  final List<FilterChipData>? filterChips;
  final String? selectedFilterValue;
  final void Function(String)? onFilterChanged;

  final List<Widget>? actionButtons;

  const CustomSearchActionView({
    super.key,
    this.searchHint,
    this.searchController,
    this.onSearchChanged,
    this.onSearchClear,
    this.filterChips,
    this.selectedFilterValue,
    this.onFilterChanged,
    this.actionButtons,
  });

  static const _indigo = Color(0xFF4F46E5);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate600 = Color(0xFF475569);
  static const _slate900 = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    if (searchHint == null && (filterChips == null || filterChips!.isEmpty) && (actionButtons == null || actionButtons!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (searchHint != null) ...[
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: GoogleFonts.inter(fontSize: 14, color: _slate900),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: GoogleFonts.inter(fontSize: 14, color: _slate400),
                prefixIcon: const Icon(Icons.search_rounded, color: _slate400, size: 20),
                suffixIcon: (searchController?.text.isNotEmpty ?? false)
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: _slate400),
                        onPressed: onSearchClear,
                      )
                    : null,
                filled: true,
                fillColor: _slate50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _slate200, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _slate200, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _indigo, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          
          if ((filterChips != null && filterChips!.isNotEmpty) || (actionButtons != null && actionButtons!.isNotEmpty)) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (filterChips != null && filterChips!.isNotEmpty)
                    ...filterChips!.map((chip) {
                      final selected = selectedFilterValue == chip.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => onFilterChanged?.call(chip.value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected ? _indigo : _slate100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? _indigo : _slate200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(chip.icon, size: 14, color: selected ? Colors.white : _slate600),
                                const SizedBox(width: 4),
                                Text(
                                  chip.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected ? Colors.white : _slate600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  if (actionButtons != null && actionButtons!.isNotEmpty)
                    ...actionButtons!.map((btn) => Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: btn,
                    )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
