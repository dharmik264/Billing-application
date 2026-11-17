import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/standalone_expense_model.dart';
import '../services/standalone_expense_service.dart';
import '../utils/app_constants.dart';
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

  List<StandaloneExpenseCategory> _categories = [];
  StandaloneExpenseCategory? _selectedCategory;
  StandaloneExpenseType _selectedType = StandaloneExpenseType.debit;
  String _paymentMode = 'CASH';
  DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  bool _isSaving = false;

  Map<String, double> _todaySummary = {'credit': 0.0, 'debit': 0.0, 'net': 0.0};
  List<StandaloneExpense> _recentExpenses = [];

  final List<String> _paymentModes = ['CASH', 'ONLINE', 'BANK_TRANSFER', 'CHEQUE'];

  @override
  void initState() {
    super.initState();
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
          // Keep selection synchronized with latest category list
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x14111111),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_box_rounded, color: Color(0xFF111111), size: 20),
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
                        'Category Name (કેટેગરીનું નામ)',
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
                            borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () async {
                    final trimmed = nameController.text.trim();
                    if (trimmed.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter category name')),
                      );
                      return;
                    }

                    // Check for duplicate locally
                    final isDuplicate = _categories.any((c) => c.name.toLowerCase() == trimmed.toLowerCase());
                    if (isDuplicate) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('આ કેટેગરી પહેલેથી હાજર છે (Category already exists)')),
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
          content: Text('મહેરબાની કરીને માન્ય રકમ દાખલ કરો (Please enter a valid amount > 0)'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      _amountFocusNode.requestFocus();
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('મહેરબાની કરીને કેટેગરી પસંદ કરો (Please select a category)'),
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

        final typeStr = _selectedType == StandaloneExpenseType.credit ? 'Credit (જમા)' : 'Debit (ખર્ચ)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$typeStr of \u20B9${amount.toStringAsFixed(2)} saved successfully!'),
            backgroundColor: _selectedType.color,
            duration: const Duration(seconds: 2),
          ),
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
        title: Text('Delete Transaction', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this ${exp.typeLabel} of \u20B9${exp.amount.toStringAsFixed(2)}?', style: GoogleFonts.inter()),
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
      backgroundColor: StitchColors.background,
      appBar: CustomAppBar(
        title: 'Expense & Cashbook',
        subtitle: 'ખર્ચ અને જમા મોડ્યુલ',
        icon: Icons.account_balance_wallet_rounded,
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Today's Financial Summary
                        _buildTodaySummaryCard(),
                        const SizedBox(height: 16),

                        // 2. Transaction Entry Card (Add Money flow)
                        _buildEntryCard(),
                        const SizedBox(height: 20),

                        // 3. Recent Transactions Feed
                        _buildRecentTransactionsSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// 1. Top Card: Today's Summary
  Widget _buildTodaySummaryCard() {
    final credit = _todaySummary['credit'] ?? 0.0;
    final debit = _todaySummary['debit'] ?? 0.0;
    final net = _todaySummary['net'] ?? 0.0;
    final isSurplus = net >= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TODAY'S CASHBOOK (આજનું બેલેન્સ)",
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF71717A),
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy').format(DateTime.now()),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF333333)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Total Credit (Green)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF2E7D32)),
                          const SizedBox(width: 4),
                          Text(
                            'Credit (જમા)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '+ \u20B9${credit.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1B5E20)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Total Debit (Red)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFC62828)),
                          const SizedBox(width: 4),
                          Text(
                            'Debit (ખર્ચ)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFC62828)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '- \u20B9${debit.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFFB71C1C)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Net Balance Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Cash Movement (ચોખ્ખું બેલેન્સ):',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF555555)),
                ),
                Text(
                  '${isSurplus ? '+' : ''}\u20B9${net.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSurplus ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Primary Entry Form: Category -> Type -> Money -> Details
  Widget _buildEntryCard() {
    final activeColor = _selectedType.color;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: Category Picker Header & Horizontal Scroll
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1. SELECT CATEGORY (કેટેગરી પસંદ કરો)',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF555555),
                  letterSpacing: 0.5,
                ),
              ),
              InkWell(
                onTap: _showAddCategoryDialog,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF1976D2)),
                      const SizedBox(width: 4),
                      Text(
                        '+ Add Category',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1976D2)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCategorySelector(),
          const SizedBox(height: 16),

          // Step 2: Credit / Debit High-Contrast Toggle
          Text(
            '2. TRANSACTION TYPE (પ્રકાર પસંદ કરો)',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF555555),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Debit Button (Red)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedType = StandaloneExpenseType.debit),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedType == StandaloneExpenseType.debit
                          ? const Color(0xFFC62828)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedType == StandaloneExpenseType.debit
                            ? const Color(0xFFC62828)
                            : const Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_circle_up_rounded,
                          size: 18,
                          color: _selectedType == StandaloneExpenseType.debit ? Colors.white : const Color(0xFFC62828),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'DEBIT / ખર્ચ (Outflow)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedType == StandaloneExpenseType.debit ? Colors.white : const Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Credit Button (Green)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedType = StandaloneExpenseType.credit),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedType == StandaloneExpenseType.credit
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedType == StandaloneExpenseType.credit
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_circle_down_rounded,
                          size: 18,
                          color: _selectedType == StandaloneExpenseType.credit ? Colors.white : const Color(0xFF2E7D32),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'CREDIT / જમા (Inflow)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedType == StandaloneExpenseType.credit ? Colors.white : const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Step 3: Enter Amount & Details
          Text(
            '3. ENTER MONEY & DETAILS (રકમ અને વિગત)',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF555555),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Amount TextField
          TextField(
            controller: _amountController,
            focusNode: _amountFocusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF111111)),
            decoration: InputDecoration(
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '\u20B9',
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: activeColor),
                ),
              ),
              hintText: '0.00',
              hintStyle: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w500, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E5E5))),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: activeColor, width: 2.0),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Payment Mode Selector
          Row(
            children: [
              Text('Mode:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF555555))),
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
                          label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF111111),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF333333)),
                          backgroundColor: const Color(0xFFF5F5F5),
                          side: BorderSide(color: isSelected ? const Color(0xFF111111) : const Color(0xFFE0E0E0)),
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
          const SizedBox(height: 10),

          // Date Selection Row
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF555555)),
                  const SizedBox(width: 8),
                  Text('Date: ', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF555555))),
                  Text(
                    DateFormat('dd MMMM yyyy').format(_selectedDate),
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111111)),
                  ),
                  const Spacer(),
                  Text(
                    'Change',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1976D2)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Note / Remarks TextField
          TextField(
            controller: _noteController,
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Add remark or notes (optional, e.g. Paid to Ramu for parcel)...',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFFAFAFA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E5E5))),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Save Transaction Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isSaving ? null : _saveTransaction,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving Entry...' : 'Save Transaction (સેવ કરો)',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Category Horizontal Selector with "+ Add Category" at front
  Widget _buildCategorySelector() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          // Index 0 is always "+ New Category" button
          if (index == 0) {
            return ActionChip(
              avatar: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF1976D2)),
              label: Text('+ Add New', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1976D2))),
              backgroundColor: const Color(0xFFE3F2FD),
              side: const BorderSide(color: Color(0xFF90CAF9)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onPressed: _showAddCategoryDialog,
            );
          }

          final category = _categories[index - 1];
          final isSelected = _selectedCategory?.id == category.id;

          return FilterChip(
            selected: isSelected,
            showCheckmark: false,
            avatar: Icon(
              category.icon,
              size: 16,
              color: isSelected ? Colors.white : category.color,
            ),
            label: Text(
              category.name,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF222222),
              ),
            ),
            backgroundColor: const Color(0xFFF5F5F5),
            selectedColor: category.color,
            side: BorderSide(
              color: isSelected ? category.color : const Color(0xFFE0E0E0),
              width: isSelected ? 1.5 : 1.0,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onSelected: (val) {
              setState(() => _selectedCategory = category);
            },
          );
        },
      ),
    );
  }

  /// 3. Recent Transactions Feed
  Widget _buildRecentTransactionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(9), topRight: Radius.circular(9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT TRANSACTIONS (છેલ્લા વ્યવહારો)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF555555),
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StandaloneExpenseReportScreen()),
                    );
                  },
                  child: Text(
                    'View All >',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1976D2)),
                  ),
                ),
              ],
            ),
          ),
          if (_recentExpenses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No transactions yet today.',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    Text(
                      'ઉપરથી નવી એન્ટ્રી સેવ કરો.',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentExpenses.length.clamp(0, 10),
              separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
              itemBuilder: (context, index) {
                final exp = _recentExpenses[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: exp.typeColor.withAlpha(30),
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
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF111111)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${exp.isCredit ? '+' : '-'} \u20B9${exp.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: exp.typeColor,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          exp.formattedPaymentMode,
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF555555)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        exp.expenseDate,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF888888)),
                      ),
                      if (exp.note != null && exp.note!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '• ${exp.note}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF666666)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                    tooltip: 'Delete',
                    onPressed: () => _deleteExpense(exp),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
