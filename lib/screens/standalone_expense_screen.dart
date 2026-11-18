import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/standalone_expense_model.dart';
import '../services/standalone_expense_service.dart';
import '../widgets/custom_page_header.dart';
import 'standalone_category_breakdown_screen.dart';
import 'standalone_expense_report_screen.dart';
import 'standalone_itemized_transactions_screen.dart';

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
  int _currentProcessStep = 0; // 0 = Category, 1 = Amount & Details

  final List<String> _paymentModes = ['CASH', 'ONLINE', 'BANK_TRANSFER', 'CHEQUE'];

  ({IconData icon, String label, Color color}) _getPaymentModeInfo(String mode) {
    switch (mode) {
      case 'ONLINE':
        return (icon: Icons.account_balance_wallet_rounded, label: 'Online / UPI', color: const Color(0xFF2563EB));
      case 'BANK_TRANSFER':
        return (icon: Icons.account_balance_rounded, label: 'Bank Transfer', color: const Color(0xFF7C3AED));
      case 'CHEQUE':
        return (icon: Icons.receipt_long_rounded, label: 'Cheque', color: const Color(0xFFD97706));
      case 'CASH':
      default:
        return (icon: Icons.payments_rounded, label: 'Cash', color: const Color(0xFF16A34A));
    }
  }

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
    final categories = await _service.getCategories();

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
              label: 'View Report',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StandaloneExpenseReportScreen()),
                );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Expense & Cashbook',
        subtitle: 'Daily Expenses & Cash Flow',
        showIcon: false,
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1D4ED8),
              side: const BorderSide(color: Color(0xFF93C5FD)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StandaloneItemizedTransactionsScreen()),
              );
            },
            icon: const Icon(Icons.receipt_long_rounded, size: 15, color: Color(0xFF1D4ED8)),
            label: Text(
              'Transactions',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
            ),
          ),
          const SizedBox(width: 8),
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
                  child: _buildAddEntryProcessView(),
                ),
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
                // Header Prompt directly on gradient with overflow protection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
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
                            'Choose or add category',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // View Breakdown Action
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const StandaloneCategoryBreakdownScreen()),
                        );
                      },
                      icon: const Icon(Icons.pie_chart_rounded, size: 15, color: Color(0xFF1D4ED8)),
                      label: Text('Breakdown', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8))),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF93C5FD)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Add Category Action Button (Properly positioned & fitted)
                    ElevatedButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('New Category', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
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
                const SizedBox(height: 12),

                // All Categories Single Dropdown Container
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
                      selectedItemBuilder: (BuildContext context) {
                        return _categories.map((category) {
                          return Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: category.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(category.icon, size: 16, color: category.color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
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
                            ],
                          );
                        }).toList();
                      },
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

                // Selected Category Preview directly on gradient (Card enclosure removed; items & text preserved)
                if (currentSelection != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: currentSelection.color.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(currentSelection.icon, size: 18, color: currentSelection.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SELECTED CATEGORY',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                currentSelection.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: currentSelection.isDefault ? Colors.white.withValues(alpha: 0.7) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: currentSelection.isDefault ? const Color(0xFFCBD5E1) : const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Text(
                            currentSelection.isDefault ? 'Default' : 'Custom',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: currentSelection.isDefault ? const Color(0xFF64748B) : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
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
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          const SizedBox(height: 6),

          // Category Selector Dropdown directly on gradient with "View All Breakdown" option
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CATEGORY',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155), letterSpacing: 0.5),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StandaloneCategoryBreakdownScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.pie_chart_rounded, size: 13, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 4),
                      Text(
                        'View All Breakdown',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory?.id,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1D4ED8), size: 24),
                hint: Row(
                  children: [
                    const Icon(Icons.category_outlined, color: Color(0xFF94A3B8), size: 18),
                    const SizedBox(width: 8),
                    Text('Select Category', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  ],
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(10),
                selectedItemBuilder: (context) {
                  return _categories.map((cat) {
                    return Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(cat.icon, size: 15, color: cat.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            cat.name,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
                items: [
                  // 1. View All Breakdown Action Option
                  DropdownMenuItem<String>(
                    value: '__VIEW_ALL_BREAKDOWN__',
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pie_chart_rounded, size: 16, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'View All (Expense Breakdown by Category)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1D4ED8)),
                        ],
                      ),
                    ),
                  ),
                  // 2. Category Items
                  ..._categories.map((cat) {
                    final isCurrent = _selectedCategory?.id == cat.id;
                    return DropdownMenuItem<String>(
                      value: cat.id,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: cat.color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(cat.icon, size: 16, color: cat.color),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                color: isCurrent ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF1D4ED8), size: 18),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  if (val == '__VIEW_ALL_BREAKDOWN__') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StandaloneCategoryBreakdownScreen()),
                    );
                  } else if (val != null) {
                    final found = _categories.cast<StandaloneExpenseCategory?>().firstWhere((c) => c?.id == val, orElse: () => null);
                    if (found != null) {
                      setState(() => _selectedCategory = found);
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // High-Contrast Credit / Debit Switcher directly on gradient
          Text(
            'TRANSACTION TYPE',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155), letterSpacing: 0.5),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              // Debit Button (Red)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedType = StandaloneExpenseType.debit),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_circle_up_rounded,
                            size: 18,
                            color: _selectedType == StandaloneExpenseType.debit ? Colors.white : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Debit (Outflow)',
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
              ),
              const SizedBox(width: 8),
              // Credit Button (Green)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedType = StandaloneExpenseType.credit),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.arrow_circle_down_rounded,
                            size: 18,
                            color: _selectedType == StandaloneExpenseType.credit ? Colors.white : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Credit (Inflow)',
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
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Enter Money Amount TextField directly on gradient
          Text(
            'ENTER AMOUNT',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155), letterSpacing: 0.5),
          ),
          const SizedBox(height: 5),
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
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    '₹',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: activeColor),
                  ),
                ),
                hintText: '0.00',
                hintStyle: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Payment Mode Selector directly on gradient (Dropdown)
          Text(
            'PAYMENT MODE',
            style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF334155), letterSpacing: 0.5),
          ),
          const SizedBox(height: 5),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _paymentMode,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1D4ED8), size: 24),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(10),
                selectedItemBuilder: (context) {
                  return _paymentModes.map((mode) {
                    final info = _getPaymentModeInfo(mode);
                    return Row(
                      children: [
                        Icon(info.icon, size: 18, color: info.color),
                        const SizedBox(width: 10),
                        Text(
                          info.label,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    );
                  }).toList();
                },
                items: _paymentModes.map((mode) {
                  final isSelected = _paymentMode == mode;
                  final info = _getPaymentModeInfo(mode);
                  return DropdownMenuItem<String>(
                    value: mode,
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: info.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(info.icon, size: 16, color: info.color),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            info.label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF1D4ED8), size: 18),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _paymentMode = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Date Selection Container directly on gradient
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text('Date: ', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                  Text(
                    DateFormat('dd MMMM yyyy').format(_selectedDate),
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
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
          const SizedBox(height: 10),

          // Notes / Remark Input directly on gradient
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
            child: TextField(
              controller: _noteController,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Add remark or notes (optional, e.g. Paid to Ramu)...',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Primary Save Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
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
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary Action: View All Itemized Transactions Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1D4ED8),
                side: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StandaloneItemizedTransactionsScreen()),
                );
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF1D4ED8)),
              label: Text(
                'View All Itemized Transactions',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
              ),
            ),
          ),
        ],
      ),
    );
  }


}
