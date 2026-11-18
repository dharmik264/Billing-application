import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/standalone_expense_model.dart';
import '../services/printer_service.dart';
import '../services/restaurant_api.dart';
import '../services/standalone_expense_service.dart';
import '../utils/app_constants.dart';
import '../widgets/custom_page_header.dart';

class StandaloneExpenseReportScreen extends StatefulWidget {
  const StandaloneExpenseReportScreen({super.key});

  @override
  State<StandaloneExpenseReportScreen> createState() => _StandaloneExpenseReportScreenState();
}

class _StandaloneExpenseReportScreenState extends State<StandaloneExpenseReportScreen> {
  final StandaloneExpenseService _service = StandaloneExpenseService.instance;
  final TextEditingController _searchController = TextEditingController();

  String _dateRangePreset = 'This Month'; // 'Today', 'Yesterday', 'This Week', 'This Month', 'Custom'
  DateTime? _startDate;
  DateTime? _endDate;

  String _selectedCategoryId = 'ALL';
  String _selectedType = 'ALL'; // 'ALL', 'CREDIT', 'DEBIT'

  List<StandaloneExpenseCategory> _categories = [];
  List<StandaloneExpense> _filteredExpenses = [];
  Map<String, double> _summary = {'credit': 0.0, 'debit': 0.0, 'net': 0.0};
  Map<String, double> _categoryBreakdown = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _applyPresetRange('This Month', reload: false);
    _loadReportData();
    _searchController.addListener(_onSearchChanged);
    _service.changeNotifier.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) _loadReportData();
  }

  void _onSearchChanged() {
    _loadReportData();
  }

  @override
  void dispose() {
    _service.changeNotifier.removeListener(_onServiceChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _applyPresetRange(String preset, {bool reload = true}) {
    final now = DateTime.now();
    _dateRangePreset = preset;

    if (preset == 'Today') {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day);
    } else if (preset == 'Yesterday') {
      final yest = now.subtract(const Duration(days: 1));
      _startDate = DateTime(yest.year, yest.month, yest.day);
      _endDate = DateTime(yest.year, yest.month, yest.day);
    } else if (preset == 'This Week') {
      final weekday = now.weekday; // 1 = Monday
      _startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
      _endDate = DateTime(now.year, now.month, now.day);
    } else if (preset == 'This Month') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month, now.day);
    }

    if (reload) {
      _loadReportData();
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 7)),
              end: DateTime.now(),
            ),
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
      setState(() {
        _dateRangePreset = 'Custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    final categories = await _service.getCategories();
    final expenses = await _service.getExpenses(
      startDate: _startDate,
      endDate: _endDate,
      categoryId: _selectedCategoryId,
      type: _selectedType,
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
    );

    double credit = 0.0;
    double debit = 0.0;
    for (final exp in expenses) {
      if (exp.isCredit) {
        credit += exp.amount;
      } else {
        debit += exp.amount;
      }
    }

    final breakdown = _service.computeCategoryDebitBreakdown(expenses);

    if (mounted) {
      setState(() {
        _categories = categories;
        _filteredExpenses = expenses;
        _summary = {
          'credit': credit,
          'debit': debit,
          'net': credit - debit,
        };
        _categoryBreakdown = breakdown;
        _isLoading = false;
      });
    }
  }

  String get _dateRangeLabel {
    if (_startDate == null || _endDate == null) return _dateRangePreset;
    final f = DateFormat('dd MMM yyyy');
    if (_startDate == _endDate) {
      return f.format(_startDate!);
    }
    return '${f.format(_startDate!)} - ${f.format(_endDate!)}';
  }

  Future<void> _printThermalReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final connected = await PrinterService.instance.isConnected;
    if (!connected) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Printer is not connected! Please connect printer from Settings.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    try {
      final shop = RestaurantApi.instance.shopData;
      final shopName = shop?.name ?? 'EASY BILL POS';
      final credit = _summary['credit'] ?? 0.0;
      final debit = _summary['debit'] ?? 0.0;
      final net = _summary['net'] ?? 0.0;

      PrinterService.instance.bluetooth
        ..printCustom(shopName.toUpperCase(), 2, 1)
        ..printCustom('EXPENSE & CASH REPORT', 1, 1)
        ..printCustom('Period: $_dateRangeLabel', 1, 0)
        ..printCustom('Generated: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}', 1, 0)
        ..printCustom('=' * 32, 1, 1)
        ..printCustom('Total Credit (+): Rs.${credit.toStringAsFixed(2)}', 1, 0)
        ..printCustom('Total Debit  (-): Rs.${debit.toStringAsFixed(2)}', 1, 0)
        ..printCustom('=' * 32, 1, 1)
        ..printCustom('NET CASH: Rs.${net.toStringAsFixed(2)}', 2, 0)
        ..printCustom('=' * 32, 1, 1);

      if (_categoryBreakdown.isNotEmpty) {
        PrinterService.instance.bluetooth
          ..printCustom('EXPENSE BREAKDOWN:', 1, 0)
          ..printCustom('-' * 32, 1, 0);
        _categoryBreakdown.forEach((catName, amt) {
          final pct = debit > 0 ? (amt / debit * 100).toStringAsFixed(1) : '0.0';
          String line = '$catName: Rs.${amt.toStringAsFixed(0)} ($pct%)';
          if (line.length > 32) line = line.substring(0, 32);
          PrinterService.instance.bluetooth.printCustom(line, 1, 0);
        });
        PrinterService.instance.bluetooth.printCustom('-' * 32, 1, 0);
      }

      PrinterService.instance.bluetooth
        ..printCustom('Total Entries: ${_filteredExpenses.length}', 1, 0)
        ..printNewLine()
        ..printNewLine()
        ..printNewLine();

      messenger.showSnackBar(
        const SnackBar(content: Text('Report printed successfully!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: const Color(0xFFC62828)),
      );
    }
  }

  Future<void> _exportPdfReport() async {
    final shop = RestaurantApi.instance.shopData;
    final shopName = shop?.name ?? 'Easy Bill Retail POS';
    final credit = _summary['credit'] ?? 0.0;
    final debit = _summary['debit'] ?? 0.0;
    final net = _summary['net'] ?? 0.0;

    final pdf = pw.Document()
      ..addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (pw.Context context) {
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Easy Bill POS - Standalone Expense System', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9)),
              ],
            );
          },
          build: (pw.Context context) {
            return [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(shopName.toUpperCase(), style: const pw.TextStyle(fontSize: 18, color: PdfColors.blueGrey900)),
                      pw.Text('Expense & Cash Flow Statement', style: const pw.TextStyle(fontSize: 14, color: PdfColors.black)),
                      pw.Text('Period: $_dateRangeLabel', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Generated On:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.grey400),
              pw.SizedBox(height: 12),

              // Financial Summary Block
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('TOTAL INFLOW (CREDIT)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.green800)),
                        pw.SizedBox(height: 4),
                        pw.Text('+ Rs. ${credit.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 14, color: PdfColors.green800)),
                      ],
                    ),
                    pw.Container(height: 30, width: 1, color: PdfColors.grey300),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('TOTAL OUTFLOW (DEBIT)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.red800)),
                        pw.SizedBox(height: 4),
                        pw.Text('- Rs. ${debit.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 14, color: PdfColors.red800)),
                      ],
                    ),
                    pw.Container(height: 30, width: 1, color: PdfColors.grey300),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('NET CASH BALANCE', style: const pw.TextStyle(fontSize: 10, color: PdfColors.blueGrey900)),
                        pw.SizedBox(height: 4),
                        pw.Text('${net >= 0 ? '+' : ''} Rs. ${net.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: net >= 0 ? PdfColors.green800 : PdfColors.red800)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Top Category Expenses Breakdown
              if (_categoryBreakdown.isNotEmpty) ...[
                pw.Text('Top Expense Categories', style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 6),
                pw.Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: _categoryBreakdown.entries.map((e) {
                    final pct = debit > 0 ? (e.value / debit * 100).toStringAsFixed(1) : '0';
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text('${e.key}: Rs. ${e.value.toStringAsFixed(0)} ($pct%)', style: const pw.TextStyle(fontSize: 9)),
                    );
                  }).toList(),
                ),
                pw.SizedBox(height: 16),
              ],

              // Itemized Transaction Table
              pw.Text('Itemized Transactions (${_filteredExpenses.length})', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Date', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Category', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Type', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Mode', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Remarks / Note', style: const pw.TextStyle(fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Amount (Rs)', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                  // Data Rows
                  ..._filteredExpenses.map((exp) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(exp.expenseDate, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(exp.categoryName, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            exp.type,
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: exp.isCredit ? PdfColors.green800 : PdfColors.red800,
                            ),
                          ),
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(exp.formattedPaymentMode, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(exp.note ?? '-', style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '${exp.isCredit ? '+' : '-'} ${exp.amount.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: exp.isCredit ? PdfColors.green800 : PdfColors.red800,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Expense_Report_${_dateRangePreset.replaceAll(' ', '_')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchColors.background,
      appBar: CustomAppBar(
        title: 'Expense & Cashflow Report',
        subtitle: 'Financial & Cash Flow Report',
        icon: Icons.bar_chart_rounded,
        actions: [
          IconButton(
            tooltip: 'Thermal Print (58/80mm)',
            icon: const Icon(Icons.print_rounded, size: 20, color: Color(0xFF111111)),
            onPressed: _printThermalReport,
          ),
          IconButton(
            tooltip: 'PDF Export / Share',
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFF111111)),
            onPressed: _exportPdfReport,
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
                // Top Filter Controls Header
                _buildFilterControls(),

                // Scrollable Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF111111)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Metric Summary Cards
                              _buildSummaryCards(),
                              const SizedBox(height: 16),

                              // 2. Category Breakdown Chart & Progress
                              if (_categoryBreakdown.isNotEmpty) ...[
                                _buildCategoryBreakdownCard(),
                                const SizedBox(height: 16),
                              ],

                              // 3. Transactions List Table
                              _buildTransactionsListCard(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Top Filter Controls Header
  Widget _buildFilterControls() {
    final presets = ['Today', 'Yesterday', 'This Week', 'This Month'];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Range Presets Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...presets.map((p) {
                  final isSelected = _dateRangePreset == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(p, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF111111),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF333333)),
                      backgroundColor: const Color(0xFFF5F5F5),
                      side: BorderSide(color: isSelected ? const Color(0xFF111111) : const Color(0xFFE0E0E0)),
                      onSelected: (val) {
                        if (val) _applyPresetRange(p);
                      },
                    ),
                  );
                }),
                // Custom Range Pill
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 14, color: Color(0xFF1976D2)),
                  label: Text(
                    _dateRangePreset == 'Custom' ? _dateRangeLabel : 'Custom Range',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: _dateRangePreset == 'Custom' ? FontWeight.w700 : FontWeight.w500,
                      color: const Color(0xFF1976D2),
                    ),
                  ),
                  backgroundColor: _dateRangePreset == 'Custom' ? const Color(0xFFE3F2FD) : const Color(0xFFF5F5F5),
                  side: BorderSide(color: _dateRangePreset == 'Custom' ? const Color(0xFF1976D2) : const Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onPressed: _pickCustomRange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Filters Row: Category Dropdown & Type Dropdown
          Row(
            children: [
              // Category Filter Dropdown
              Expanded(
                flex: 3,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategoryId,
                      isExpanded: true,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF111111)),
                      items: [
                        const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                        ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategoryId = val);
                          _loadReportData();
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Type Filter (All, Credit, Debit)
              Expanded(
                flex: 2,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF111111)),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Types')),
                        DropdownMenuItem(value: 'CREDIT', child: Text('Credit (Inflow)')),
                        DropdownMenuItem(value: 'DEBIT', child: Text('Debit (Outflow)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedType = val);
                          _loadReportData();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 1. Metric Summary Cards
  Widget _buildSummaryCards() {
    final credit = _summary['credit'] ?? 0.0;
    final debit = _summary['debit'] ?? 0.0;
    final net = _summary['net'] ?? 0.0;
    final isSurplus = net >= 0;

    final creditCount = _filteredExpenses.where((e) => e.isCredit).length;
    final debitCount = _filteredExpenses.where((e) => e.isDebit).length;

    return Row(
      children: [
        // Credit Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Inflow (Credit)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32))),
                    Text('$creditCount txns', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '+ \u20B9${credit.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF1B5E20)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Debit Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Outflow (Debit)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFC62828))),
                    Text('$debitCount txns', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '- \u20B9${debit.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFFB71C1C)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Net Balance Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Net Balance', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF555555))),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${isSurplus ? '+' : ''}\u20B9${net.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isSurplus ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 2. Category Breakdown Card
  Widget _buildCategoryBreakdownCard() {
    final debit = _summary['debit'] ?? 0.0;
    final sortedEntries = _categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'EXPENSE BREAKDOWN BY CATEGORY',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF555555),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedEntries.map((e) {
            final percentage = debit > 0 ? (e.value / debit) : 0.0;
            final pctStr = (percentage * 100).toStringAsFixed(1);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF222222))),
                      Text('\u20B9${e.value.toStringAsFixed(2)} ($pctStr%)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF111111))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: const Color(0xFFF0F0F0),
                      color: const Color(0xFFC62828),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 3. Transactions List Table
  Widget _buildTransactionsListCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.only(topLeft: Radius.circular(7), topRight: Radius.circular(7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ITEMIZED TRANSACTIONS (${_filteredExpenses.length})',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF555555),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  _dateRangeLabel,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF666666)),
                ),
              ],
            ),
          ),
          if (_filteredExpenses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'No transactions found for selected filters.',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredExpenses.length,
              separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
              itemBuilder: (context, index) {
                final exp = _filteredExpenses[index];
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
                );
              },
            ),
        ],
      ),
    );
  }
}
