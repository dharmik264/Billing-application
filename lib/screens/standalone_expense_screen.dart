import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/standalone_expense_model.dart';
import '../services/standalone_expense_service.dart';
import '../widgets/custom_page_header.dart';
import 'standalone_expense_report_screen.dart';

class StandaloneExpenseScreen extends StatefulWidget {
  const StandaloneExpenseScreen({super.key});

  @override
  State<StandaloneExpenseScreen> createState() => _StandaloneExpenseScreenState();
}

class _StandaloneExpenseScreenState extends State<StandaloneExpenseScreen> {
  final StandaloneExpenseService _service = StandaloneExpenseService.instance;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  late final PageController _pageController;

  List<StandaloneExpenseCategory> _categories = [];
  StandaloneExpenseCategory? _selectedCategory;
  StandaloneExpenseType _selectedType = StandaloneExpenseType.debit;
  String _paymentMode = 'CASH';
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  bool _isSaving = false;

  // 0 = Add Entry Process (2 pages: Step 1 Category, Step 2 Amount)
  // 1 = Cashbook & History (Today's summary & recent transactions)
  int _activeTab = 0;
  int _currentProcessStep = 0; // 0 = Category, 1 = Amount & Details

  Map<String, double> _todaySummary = {'credit': 0.0, 'debit': 0.0, 'net': 0.0};
  List<StandaloneExpense> _recentExpenses = [];

  final List<String> _paymentModes = ['CASH', 'ONLINE', 'BANK_TRANSFER', 'CHEQUE'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _loadInitialData();
    _service.changeNotifier.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _service.changeNotifier.removeListener(_onServiceChanged);
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _loadData();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final categories = await _service.getCategories();
    final summary = await _service.getSummary(
      startDate: now,
      endDate: now,
    );
    final recents = await _service.getExpenses(
      startDate: now.subtract(const Duration(days: 3)),
      endDate: now,
    );

    if (mounted) {
      setState(() {
        _categories = categories;
        if (_selectedCategory == null && _categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        } else if (_selectedCategory != null) {
          final found = _categories.where((c) => c.id == _selectedCategory!.id);
          if (found.isNotEmpty) {
            _selectedCategory = found.first;
          } else if (_categories.isNotEmpty) {
            _selectedCategory = _categories.first;
          }
        }
        _todaySummary = summary;
        _recentExpenses = recents;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF111111),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111111),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    String selectedIcon = 'category';
    String selectedColor = '#FF7043';

    final iconOptions = [
      {'name': 'category', 'icon': Icons.category_rounded, 'label': 'General'},
      {'name': 'local_cafe', 'icon': Icons.local_cafe_rounded, 'label': 'Tea/Food'},
      {'name': 'storefront', 'icon': Icons.storefront_rounded, 'label': 'Rent/Store'},
      {'name': 'bolt', 'icon': Icons.bolt_rounded, 'label': 'Power/Light'},
      {'name': 'badge', 'icon': Icons.badge_rounded, 'label': 'Salary'},
      {'name': 'local_shipping', 'icon': Icons.local_shipping_rounded, 'label': 'Transport'},
      {'name': 'build', 'icon': Icons.build_rounded, 'label': 'Repairs'},
      {'name': 'account_balance', 'icon': Icons.account_balance_rounded, 'label': 'Supplier'},
      {'name': 'account_balance_wallet', 'icon': Icons.account_balance_wallet_rounded, 'label': 'Capital'},
      {'name': 'assignment_return', 'icon': Icons.assignment_return_rounded, 'label': 'Refund'},
      {'name': 'savings', 'icon': Icons.savings_rounded, 'label': 'Savings'},
      {'name': 'shopping_cart', 'icon': Icons.shopping_cart_rounded, 'label': 'Items'},
    ];

    final colorOptions = [
      '#FF7043', // Deep Orange
      '#5C6BC0', // Indigo
      '#FBC02D', // Amber
      '#00897B', // Teal
      '#8D6E63', // Brown
      '#78909C', // Blue Grey
      '#8E24AA', // Purple
      '#2E7D32', // Green
      '#0288D1', // Light Blue
      '#E53935', // Red
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_box_rounded, color: Color(0xFF1D4ED8), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Add New Category',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category Name',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF555555)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'e.g. Tea & Snacks, Shop Rent...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select Icon',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF555555)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: iconOptions.map((opt) {
                          final isSelected = selectedIcon == opt['name'];
                          return InkWell(
                            onTap: () => setDialogState(() => selectedIcon = opt['name'] as String),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF111111) : const Color(0xFFE0E0E0),
                                ),
                              ),
                              child: Icon(
                                opt['icon'] as IconData,
                                size: 20,
                                color: isSelected ? Colors.white : const Color(0xFF333333),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select Color Theme',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF555555)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: colorOptions.map((hex) {
                          final isSelected = selectedColor == hex;
                          final colorVal = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                          return InkWell(
                            onTap: () => setDialogState(() => selectedColor = hex),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: colorVal,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF111111) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey.shade700)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onPressed: () async {
                    final trimmed = nameController.text.trim();
                    if (trimmed.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter category name')),
                      );
                      return;
                    }

                    final isDuplicate = _categories.any((c) => c.name.toLowerCase() == trimmed.toLowerCase());
                    if (isDuplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Category already exists')),
                      );
                      return;
                    }

                    final newCategory = StandaloneExpenseCategory(
                      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
                      name: trimmed,
                      iconName: selectedIcon,
                      colorHex: selectedColor,
                      isDefault: false,
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await _service.addCategory(newCategory);
                    if (ctx.mounted) Navigator.pop(ctx);

                    if (ok && mounted) {
                      setState(() {
                        _selectedCategory = newCategory;
                      });
                      messenger.showSnackBar(
                        SnackBar(content: Text('Category "$trimmed" added successfully!')),
                      );
                    }
                  },
                  child: Text('Add Category', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveTransaction() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount > 0'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      _amountFocusNode.requestFocus();
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final formatter = DateFormat('yyyy-MM-dd');
    final formattedDate = formatter.format(_selectedDate);

    final expense = StandaloneExpense(
      id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
      categoryId: _selectedCategory!.id,
      categoryName: _selectedCategory!.name,
      type: _selectedType.value,
      amount: amount,
      paymentMode: _paymentMode,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      expenseDate: formattedDate,
    );

    final ok = await _service.addExpense(expense);

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        _amountController.clear();
        _noteController.clear();
        FocusScope.of(context).unfocus();

        final typeStr = _selectedType == StandaloneExpenseType.credit ? 'Credit' : 'Debit';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$typeStr of ₹${amount.toStringAsFixed(2)} saved successfully!'),
            backgroundColor: _selectedType.color,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View Cashbook',
              textColor: Colors.white,
              onPressed: () {
                setState(() => _activeTab = 1);
              },
            ),
          ),
        );

        // Reset process back to page 0 for next entry
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save transaction. Please try again.'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense(StandaloneExpense exp) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Transaction', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this ${exp.typeLabel} of ₹${exp.amount.toStringAsFixed(2)}?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.deleteExpense(exp.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Expense & Cashbook',
        subtitle: 'Daily Expenses & Cash Flow',
        icon: Icons.account_balance_wallet_rounded,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StandaloneExpenseReportScreen()),
              );
            },
            icon: const Icon(Icons.bar_chart_rounded, size: 16, color: Colors.white),
            label: Text(
              'Report',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF111111)))
          : SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      // Top Navigation Switcher: [➕ New Entry Process (2 Pages)] | [📖 Cashbook & History]
                      _buildTopNavigationTabs(),

                      // Active View Body
                      Expanded(
                        child: _activeTab == 0
                            ? _buildAddEntryProcessView()
                            : _buildCashbookHistoryView(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /// Top Segmented Navigation (No heavy cards - sits directly on gradient)
  Widget _buildTopNavigationTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Tab 1: New Entry Process (2 Pages)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _activeTab = 0),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _activeTab == 0 ? const Color(0xFF111111) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 16,
                        color: _activeTab == 0 ? Colors.white : const Color(0xFF555555),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '➕ New Entry (2 Pages)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _activeTab == 0 ? Colors.white : const Color(0xFF555555),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Tab 2: Cashbook & Ledger
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _activeTab = 1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _activeTab == 1 ? const Color(0xFF111111) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 16,
                        color: _activeTab == 1 ? Colors.white : const Color(0xFF555555),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '📖 Cashbook & Ledger',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _activeTab == 1 ? Colors.white : const Color(0xFF555555),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// PROCESS VIEW: DIVIDED INTO 2 PAGES (PAGE 1: CATEGORY, PAGE 2: AMOUNT & TYPE)
  /// Sits directly on top of gradient without any outer Card container!
  /// --------------------------------------------------------------------------
  Widget _buildAddEntryProcessView() {
    return Column(
      children: [
        // Two-Step Progress Indicator
        _buildProcessStepIndicator(),

        // PageView holding Page 1 (Category) and Page 2 (Amount & Details)
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (idx) {
              setState(() => _currentProcessStep = idx);
            },
            children: [
              // PAGE 1: Category Selection & Creation
              _buildPage1CategorySelection(),

              // PAGE 2: Amount, Credit/Debit & Save
              _buildPage2AmountAndDetails(),
            ],
          ),
        ),
      ],
    );
  }

  /// Modern 2-Step Bar Indicator directly on gradient
  Widget _buildProcessStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Step 1 Pill
          Expanded(
            child: InkWell(
              onTap: () {
                _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: _currentProcessStep == 0 ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _currentProcessStep == 0 ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                    width: _currentProcessStep == 0 ? 1.8 : 1.0,
                  ),
                  boxShadow: _currentProcessStep == 0
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: _currentProcessStep == 0 ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                      child: Text('1', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '1. Select Category',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: _currentProcessStep == 0 ? FontWeight.w700 : FontWeight.w500,
                          color: _currentProcessStep == 0 ? const Color(0xFF111111) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedCategory != null)
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
          ),
          // Step 2 Pill
          Expanded(
            child: InkWell(
              onTap: () {
                if (_selectedCategory != null) {
                  _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: _currentProcessStep == 1 ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _currentProcessStep == 1 ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                    width: _currentProcessStep == 1 ? 1.8 : 1.0,
                  ),
                  boxShadow: _currentProcessStep == 1
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: _currentProcessStep == 1 ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                      child: Text('2', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '2. Amount & Type',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: _currentProcessStep == 1 ? FontWeight.w700 : FontWeight.w500,
                          color: _currentProcessStep == 1 ? const Color(0xFF111111) : const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// PAGE 1: CATEGORY SELECTION & ADD CATEGORY (NO CARD ENCLOSURE)
  /// --------------------------------------------------------------------------
  Widget _buildPage1CategorySelection() {
    // Ensure currently selected category is valid within _categories list
    final StandaloneExpenseCategory? currentSelection = _categories.any((c) => c.id == _selectedCategory?.id)
        ? _categories.firstWhere((c) => c.id == _selectedCategory?.id)
        : (_categories.isNotEmpty ? _categories.first : null);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Prompt directly on gradient
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SELECT CATEGORY',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose a category from the dropdown below',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    // Add Category Action Button
                    ElevatedButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('+ New Category', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // All Categories Single Dropdown Container
                Text(
                  'CATEGORY DROPDOWN',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<StandaloneExpenseCategory>(
                      value: currentSelection,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1D4ED8), size: 26),
                      hint: Row(
                        children: [
                          const Icon(Icons.category_outlined, color: Color(0xFF94A3B8), size: 20),
                          const SizedBox(width: 10),
                          Text('Select Category', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
                        ],
                      ),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      items: _categories.map((category) {
                        final isItemCurrent = currentSelection?.id == category.id;
                        return DropdownMenuItem<StandaloneExpenseCategory>(
                          value: category,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: category.color.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(category.icon, size: 18, color: category.color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    category.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: isItemCurrent ? FontWeight.w700 : FontWeight.w600,
                                      color: isItemCurrent ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: category.isDefault ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: category.isDefault ? const Color(0xFFCBD5E1) : const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: Text(
                                    category.isDefault ? 'Default' : 'Custom',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: category.isDefault ? const Color(0xFF64748B) : const Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                                if (isItemCurrent) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_rounded, color: Color(0xFF1D4ED8), size: 18),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (StandaloneExpenseCategory? newCat) {
                        if (newCat != null) {
                          setState(() => _selectedCategory = newCat);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Selected Category Preview Box directly on gradient
                if (currentSelection != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: currentSelection.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(currentSelection.icon, size: 26, color: currentSelection.color),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SELECTED CATEGORY',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentSelection.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentSelection.isDefault ? 'Default Category' : 'Custom Category',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_categories.length} categories available in dropdown',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                            ),
                            TextButton.icon(
                              onPressed: _showAddCategoryDialog,
                              icon: const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF1D4ED8)),
                              label: Text(
                                '+ Add New Category',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1D4ED8)),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Bottom Action Footer directly on gradient (Page 1 -> Page 2)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedCategory != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Selected: ', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      Icon(_selectedCategory!.icon, size: 14, color: _selectedCategory!.color),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCategory!.name,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedCategory == null
                      ? null
                      : () {
                          _pageController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                    shadowColor: Colors.black26,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next: Enter Amount & Details',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// --------------------------------------------------------------------------
  /// PAGE 2: AMOUNT, CREDIT/DEBIT TOGGLE & SAVE (NO CARD ENCLOSURE)
  /// --------------------------------------------------------------------------
  Widget _buildPage2AmountAndDetails() {
    final activeColor = _selectedType.color;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 2 Header & Change Category Action directly on gradient
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF1D4ED8)),
                label: Text(
                  'Change Category',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text('Step 2 of 2', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Selected Category Floating Pill Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _selectedCategory?.color.withValues(alpha: 0.15) ?? const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_selectedCategory?.icon ?? Icons.category, color: _selectedCategory?.color ?? Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SELECTED CATEGORY', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                      Text(
                        _selectedCategory?.name ?? 'General',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  child: Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // High-Contrast Credit / Debit Switcher directly on gradient
          Text(
            'TRANSACTION TYPE',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155), letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Debit / Expense Button (Red)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedType = StandaloneExpenseType.debit),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedType == StandaloneExpenseType.debit ? const Color(0xFFDC2626) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedType == StandaloneExpenseType.debit ? const Color(0xFFDC2626) : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _selectedType == StandaloneExpenseType.debit
                              ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_circle_up_rounded,
                          size: 20,
                          color: _selectedType == StandaloneExpenseType.debit ? Colors.white : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'DEBIT / Expense (Outflow)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedType == StandaloneExpenseType.debit ? Colors.white : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Credit / Income Button (Green)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedType = StandaloneExpenseType.credit),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedType == StandaloneExpenseType.credit ? const Color(0xFF16A34A) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedType == StandaloneExpenseType.credit ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _selectedType == StandaloneExpenseType.credit
                              ? const Color(0xFF16A34A).withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_circle_down_rounded,
                          size: 20,
                          color: _selectedType == StandaloneExpenseType.credit ? Colors.white : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CREDIT / Income (Inflow)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedType == StandaloneExpenseType.credit ? Colors.white : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Enter Money Amount TextField directly on gradient
          Text(
            'ENTER AMOUNT',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155), letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    '₹',
                    style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: activeColor),
                  ),
                ),
                hintText: '0.00',
                hintStyle: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Payment Mode Selector directly on gradient
          Row(
            children: [
              Text('Mode:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF475569))),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _paymentModes.map((mode) {
                      final isSelected = _paymentMode == mode;
                      String label = 'Cash';
                      if (mode == 'ONLINE') label = 'Online/UPI';
                      if (mode == 'BANK_TRANSFER') label = 'Bank';
                      if (mode == 'CHEQUE') label = 'Cheque';

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF111111),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF334155)),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: isSelected ? const Color(0xFF111111) : const Color(0xFFCBD5E1)),
                          onSelected: (val) {
                            if (val) setState(() => _paymentMode = mode);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date Selection Container directly on gradient
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  Text('Date: ', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  Text(
                    DateFormat('dd MMMM yyyy').format(_selectedDate),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  Text(
                    'Change Date',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Notes / Remark Input directly on gradient
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _noteController,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Add remark or notes (optional, e.g. Paid to Ramu for shop supplies)...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Primary Save Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving ? null : _saveTransaction,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving Entry...' : 'Save Transaction',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// --------------------------------------------------------------------------
  /// CASHBOOK & LEDGER VIEW: TODAY'S TOTALS + TRANSACTIONS (NO CARD ENCLOSURE)
  /// Sits directly on top of gradient without any outer Card container!
  /// --------------------------------------------------------------------------
  Widget _buildCashbookHistoryView() {
    final credit = _todaySummary['credit'] ?? 0.0;
    final debit = _todaySummary['debit'] ?? 0.0;
    final net = _todaySummary['net'] ?? 0.0;
    final isSurplus = net >= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title directly on gradient
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TODAY'S CASHBOOK",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Financial Summary Pills directly on gradient (No enclosing Card!)
          Row(
            children: [
              // Total Credit (Green Pill)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text(
                            'Credit (Inflow)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '+ ₹${credit.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Total Debit (Red Pill)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFDC2626)),
                          const SizedBox(width: 4),
                          Text(
                            'Debit (Outflow)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '- ₹${debit.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFFB91C1C)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Net Movement Bar directly on gradient
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Cash Movement:',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                ),
                Text(
                  '${isSurplus ? '+' : ''}₹${net.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isSurplus ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Transactions Header directly on gradient
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT TRANSACTIONS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  letterSpacing: 0.5,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StandaloneExpenseReportScreen()),
                  );
                },
                child: Text('View Full Report >', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // List of individual floating transaction items directly on gradient (No card enclosure!)
          if (_recentExpenses.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text(
                    'No transactions recorded today yet.',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Go to "➕ New Entry" tab to record a transaction.',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentExpenses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final exp = _recentExpenses[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: exp.typeColor.withValues(alpha: 0.15),
                        child: Icon(
                          exp.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: exp.typeColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exp.categoryName,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    exp.formattedPaymentMode,
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF475569)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  exp.expenseDate,
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            if (exp.note != null && exp.note!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                exp.note!,
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${exp.isCredit ? '+' : '-'} ₹${exp.amount.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: exp.typeColor,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                            tooltip: 'Delete',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteExpense(exp),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
