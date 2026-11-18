import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/standalone_expense_model.dart';
import '../services/standalone_expense_service.dart';
import '../utils/app_constants.dart';
import '../widgets/custom_page_header.dart';

class StandaloneItemizedTransactionsScreen extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? initialPreset;
  final String? initialCategoryId;
  final String? initialType;

  const StandaloneItemizedTransactionsScreen({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialPreset,
    this.initialCategoryId,
    this.initialType,
  });

  @override
  State<StandaloneItemizedTransactionsScreen> createState() => _StandaloneItemizedTransactionsScreenState();
}

class _StandaloneItemizedTransactionsScreenState extends State<StandaloneItemizedTransactionsScreen> {
  final StandaloneExpenseService _service = StandaloneExpenseService.instance;
  final TextEditingController _searchController = TextEditingController();

  late String _dateRangePreset;
  DateTime? _startDate;
  DateTime? _endDate;

  String _selectedCategoryId = 'ALL';
  String _selectedType = 'ALL'; // 'ALL', 'CREDIT', 'DEBIT'
  String _selectedPaymentMode = 'ALL'; // 'ALL', 'CASH', 'ONLINE', 'BANK_TRANSFER', 'CHEQUE'

  List<StandaloneExpenseCategory> _categories = [];
  List<StandaloneExpense> _expenses = [];
  List<StandaloneExpense> _filteredExpenses = [];

  double _totalCredit = 0.0;
  double _totalDebit = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _dateRangePreset = widget.initialPreset ?? 'This Month';
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _selectedCategoryId = widget.initialCategoryId ?? 'ALL';
    _selectedType = widget.initialType ?? 'ALL';

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

      setState(() {
        _categories = categories;
        _expenses = expenses;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading itemized transactions: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _expenses.where((exp) {
      // 1. Category Filter
      if (_selectedCategoryId != 'ALL' && exp.categoryId != _selectedCategoryId) {
        return false;
      }

      // 2. Type Filter
      if (_selectedType != 'ALL' && exp.type.toUpperCase() != _selectedType) {
        return false;
      }

      // 3. Payment Mode Filter
      if (_selectedPaymentMode != 'ALL') {
        final mode = exp.paymentMode.toUpperCase();
        if (_selectedPaymentMode == 'ONLINE' && (mode != 'ONLINE' && mode != 'UPI')) {
          return false;
        } else if (_selectedPaymentMode == 'BANK_TRANSFER' && (mode != 'BANK_TRANSFER' && mode != 'BANK')) {
          return false;
        } else if (_selectedPaymentMode != 'ONLINE' && _selectedPaymentMode != 'BANK_TRANSFER' && mode != _selectedPaymentMode) {
          return false;
        }
      }

      // 4. Search Filter (Category, Note, or Amount)
      if (query.isNotEmpty) {
        final catMatch = exp.categoryName.toLowerCase().contains(query);
        final noteMatch = exp.note?.toLowerCase().contains(query) ?? false;
        final amountMatch = exp.amount.toString().contains(query);
        if (!catMatch && !noteMatch && !amountMatch) {
          return false;
        }
      }

      return true;
    }).toList();

    double cr = 0.0;
    double db = 0.0;
    for (final e in filtered) {
      if (e.isCredit) {
        cr += e.amount;
      } else {
        db += e.amount;
      }
    }

    _filteredExpenses = filtered;
    _totalCredit = cr;
    _totalDebit = db;
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

  Future<void> _confirmDeleteExpense(StandaloneExpense exp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Delete Transaction?',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
        content: Text(
          'Are you sure you want to delete this ${exp.typeLabel.toLowerCase()} of ₹${exp.amount.toStringAsFixed(2)} for "${exp.categoryName}"?',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _service.deleteExpense(exp.id);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaction deleted successfully'), backgroundColor: Color(0xFF16A34A)),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete transaction'), backgroundColor: Color(0xFFDC2626)),
          );
        }
      }
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
          title: 'Itemized Transactions',
          subtitle: 'All expense & cashflow transactions',
          icon: Icons.receipt_long_rounded,
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
                  // Filter bar directly on gradient
                  _buildFilterBar(),

                  // Scrollable Content
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

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Date Range Dropdown
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

          // 2. Filter Row: Category & Type & Payment Mode
          Row(
            children: [
              // Category Filter Dropdown
              Expanded(
                flex: 3,
                child: Container(
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1D4ED8), size: 20),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      selectedItemBuilder: (context) {
                        return [
                          Row(
                            children: [
                              const Icon(Icons.category_outlined, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('All Categories', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          ..._categories.map((c) {
                            return Row(
                              children: [
                                Icon(c.icon, size: 16, color: c.color),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(c.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            );
                          }),
                        ];
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text('All Categories (${_categories.length})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        ),
                        ..._categories.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Row(
                              children: [
                                Icon(c.icon, size: 16, color: c.color),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(c.name, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategoryId = val;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Type Filter Dropdown
              Expanded(
                flex: 2,
                child: Container(
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1D4ED8), size: 20),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      items: [
                        DropdownMenuItem(
                          value: 'ALL',
                          child: Text('All Types', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                        ),
                        DropdownMenuItem(
                          value: 'DEBIT',
                          child: Text('Debit (-)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
                        ),
                        DropdownMenuItem(
                          value: 'CREDIT',
                          child: Text('Credit (+)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A))),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedType = val;
                            _applyFilters();
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Payment Mode Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPaymentModeFilterChip('ALL', 'All Modes', Icons.filter_alt_outlined),
                const SizedBox(width: 6),
                _buildPaymentModeFilterChip('CASH', 'Cash', Icons.payments_rounded),
                const SizedBox(width: 6),
                _buildPaymentModeFilterChip('ONLINE', 'Online / UPI', Icons.account_balance_wallet_rounded),
                const SizedBox(width: 6),
                _buildPaymentModeFilterChip('BANK_TRANSFER', 'Bank', Icons.account_balance_rounded),
                const SizedBox(width: 6),
                _buildPaymentModeFilterChip('CHEQUE', 'Cheque', Icons.receipt_long_rounded),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3. Search Bar
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
              onChanged: (_) => setState(_applyFilters),
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(_applyFilters);
                        },
                      )
                    : null,
                hintText: 'Search note, category, or amount...',
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

  Widget _buildPaymentModeFilterChip(String mode, String label, IconData icon) {
    final isSelected = _selectedPaymentMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPaymentMode = mode;
          _applyFilters();
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : const Color(0xFF475569)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL OUTFLOW',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626)),
                    ),
                    Text(
                      '₹${_totalDebit.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'TRANSACTIONS',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                    ),
                    Text(
                      '${_filteredExpenses.length}',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL INFLOW',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A)),
                    ),
                    Text(
                      '₹${_totalCredit.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Transactions List Card
          Container(
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
            child: _filteredExpenses.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 44, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          Text(
                            'No transactions match selected filters',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filteredExpenses.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final exp = _filteredExpenses[index];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: exp.typeColor.withValues(alpha: 0.14),
                          radius: 18,
                          child: Icon(
                            exp.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            color: exp.typeColor,
                            size: 18,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                exp.categoryName,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${exp.isCredit ? '+' : '-'} ₹${exp.amount.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: exp.typeColor,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  exp.formattedPaymentMode,
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                exp.expenseDate,
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                              ),
                              if (exp.note != null && exp.note!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '• ${exp.note}',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                          tooltip: 'Delete transaction',
                          onPressed: () => _confirmDeleteExpense(exp),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
