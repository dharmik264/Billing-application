import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/standalone_expense_model.dart';
import '../services/standalone_expense_service.dart';
import '../utils/app_constants.dart';
import '../widgets/custom_page_header.dart';
import 'standalone_itemized_transactions_screen.dart';

class CategoryBreakdownItem {
  final String categoryId;
  final String categoryName;
  final IconData icon;
  final Color color;
  final double debitAmount;
  final double creditAmount;
  final int transactionCount;

  CategoryBreakdownItem({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.debitAmount,
    required this.creditAmount,
    required this.transactionCount,
  });
}

class StandaloneCategoryBreakdownScreen extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? initialPreset;

  const StandaloneCategoryBreakdownScreen({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialPreset,
  });

  @override
  State<StandaloneCategoryBreakdownScreen> createState() => _StandaloneCategoryBreakdownScreenState();
}

class _StandaloneCategoryBreakdownScreenState extends State<StandaloneCategoryBreakdownScreen> {
  final StandaloneExpenseService _service = StandaloneExpenseService.instance;
  final TextEditingController _searchController = TextEditingController();

  late String _dateRangePreset;
  DateTime? _startDate;
  DateTime? _endDate;

  List<StandaloneExpense> _expenses = [];
  List<CategoryBreakdownItem> _breakdownItems = [];
  List<CategoryBreakdownItem> _filteredItems = [];

  double _totalDebit = 0.0;
  double _totalCredit = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _dateRangePreset = widget.initialPreset ?? 'This Month';
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;

    if (_startDate == null || _endDate == null) {
      _applyPresetDateRange(_dateRangePreset);
    }

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyPresetDateRange(String preset) {
    final now = DateTime.now();
    _dateRangePreset = preset;

    switch (preset) {
      case 'Today':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Yesterday':
        final yest = now.subtract(const Duration(days: 1));
        _startDate = DateTime(yest.year, yest.month, yest.day);
        _endDate = DateTime(yest.year, yest.month, yest.day, 23, 59, 59);
        break;
      case 'This Week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(monday.year, monday.month, monday.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'This Month':
      default:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
    }
  }

  String get _dateRangeLabel {
    final f = DateFormat('dd MMM yyyy');
    if (_startDate == null || _endDate == null) return 'All Time';
    return '${f.format(_startDate!)} - ${f.format(_endDate!)}';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final categories = await _service.getCategories();
      final expenses = await _service.getExpenses(
        startDate: _startDate,
        endDate: _endDate,
      );

      final Map<String, StandaloneExpenseCategory> catMap = {
        for (final c in categories) c.id: c,
      };

      final Map<String, double> debitMap = {};
      final Map<String, double> creditMap = {};
      final Map<String, int> countMap = {};
      final Map<String, String> catIdMap = {};

      double totDebit = 0.0;
      double totCredit = 0.0;

      for (final exp in expenses) {
        final catName = exp.categoryName.isNotEmpty ? exp.categoryName : 'General';
        catIdMap[catName] = exp.categoryId;

        if (exp.isDebit) {
          debitMap[catName] = (debitMap[catName] ?? 0.0) + exp.amount;
          totDebit += exp.amount;
        } else if (exp.isCredit) {
          creditMap[catName] = (creditMap[catName] ?? 0.0) + exp.amount;
          totCredit += exp.amount;
        }
        countMap[catName] = (countMap[catName] ?? 0) + 1;
      }

      final List<CategoryBreakdownItem> items = [];
      final allCategoryNames = <String>{...debitMap.keys, ...creditMap.keys};

      for (final name in allCategoryNames) {
        final catId = catIdMap[name] ?? '';
        final catObj = catMap[catId] ??
            categories.cast<StandaloneExpenseCategory?>().firstWhere(
                  (c) => c?.name.toLowerCase() == name.toLowerCase(),
                  orElse: () => null,
                );

        items.add(CategoryBreakdownItem(
          categoryId: catId,
          categoryName: name,
          icon: catObj?.icon ?? Icons.category_rounded,
          color: catObj?.color ?? const Color(0xFF1976D2),
          debitAmount: debitMap[name] ?? 0.0,
          creditAmount: creditMap[name] ?? 0.0,
          transactionCount: countMap[name] ?? 0,
        ));
      }

      // Sort items by debit amount descending (highest outflow first)
      items.sort((a, b) => b.debitAmount.compareTo(a.debitAmount));

      setState(() {
        _expenses = expenses;
        _breakdownItems = items;
        _totalDebit = totDebit;
        _totalCredit = totCredit;
        _filterList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading category breakdown: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterList() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredItems = List.from(_breakdownItems);
    } else {
      _filteredItems = _breakdownItems.where((item) {
        return item.categoryName.toLowerCase().contains(query);
      }).toList();
    }
  }

  Future<void> _openCustomDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1D4ED8),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _dateRangePreset = 'Custom';
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: 'Expense Breakdown by Category',
          subtitle: 'Category-wise expense distribution',
          icon: Icons.pie_chart_rounded,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 20),
              tooltip: 'Refresh',
              onPressed: _loadData,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Filter header on gradient
                  _buildFilterHeader(),

                  // Main Content
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF1D4ED8)))
                        : _buildMainContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          // Date Range Dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: ['Today', 'Yesterday', 'This Week', 'This Month', 'Custom'].contains(_dateRangePreset)
                    ? _dateRangePreset
                    : 'Custom',
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1D4ED8), size: 22),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(10),
                selectedItemBuilder: (context) {
                  return ['Today', 'Yesterday', 'This Week', 'This Month', 'Custom'].map((p) {
                    return Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p == 'Custom' ? 'Custom Range ($_dateRangeLabel)' : '$p ($_dateRangeLabel)',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
                items: [
                  DropdownMenuItem(
                    value: 'Today',
                    child: Row(
                      children: [
                        const Icon(Icons.today_rounded, size: 16, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Text('Today', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Yesterday',
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 16, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Text('Yesterday', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'This Week',
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Text('This Week', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'This Month',
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Text('This Month', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Custom',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_calendar_rounded, size: 16, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Custom Date Picker...',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  if (val == 'Custom') {
                    _openCustomDatePicker();
                  } else {
                    setState(() => _applyPresetDateRange(val));
                    _loadData();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Search categories input
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(_filterList),
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(_filterList);
                        },
                      )
                    : null,
                hintText: 'Search category by name...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary Banner Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL EXPENSES (DEBIT)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_totalDebit.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      Text(
                        'Across ${_breakdownItems.length} active categories',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 44,
                  width: 1,
                  color: const Color(0xFFE2E8F0),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTAL INFLOW (CREDIT)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF16A34A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_totalCredit.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                      Text(
                        '${_expenses.length} total entries',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Categories Breakdown List
          if (_filteredItems.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.pie_chart_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    Text(
                      'No expense records found',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try changing the date filter or adding new transactions.',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                final percentage = _totalDebit > 0 ? (item.debitAmount / _totalDebit) : 0.0;
                final pctStr = (percentage * 100).toStringAsFixed(1);

                return InkWell(
                  onTap: () {
                    // Navigate to Itemized transactions screen filtered for this category!
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StandaloneItemizedTransactionsScreen(
                          initialStartDate: _startDate,
                          initialEndDate: _endDate,
                          initialPreset: _dateRangePreset,
                          initialCategoryId: item.categoryId.isNotEmpty ? item.categoryId : 'ALL',
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item.icon, size: 20, color: item.color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.categoryName,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    '${item.transactionCount} transaction${item.transactionCount == 1 ? '' : 's'}',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${item.debitAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Text(
                                    '$pctStr% of expenses',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Progress indicator
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage.clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation<Color>(item.color),
                          ),
                        ),
                        if (item.creditAmount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Inflow received in this category:',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                              Text(
                                '+ ₹${item.creditAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
