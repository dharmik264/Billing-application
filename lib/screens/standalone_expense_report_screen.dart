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
import '../widgets/custom_page_header.dart';
import 'standalone_category_breakdown_screen.dart';
import 'standalone_itemized_transactions_screen.dart';

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
  Map<String, double> _summary = {
    'credit': 0.0,
    'debit': 0.0,
    'net': 0.0,
    'cashInflow': 0.0,
    'cashOutflow': 0.0,
    'onlineInflow': 0.0,
    'onlineOutflow': 0.0,
  };
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

  Future<void> _pickCustomRangeWithPresets() async {
    final now = DateTime.now();
    DateTime tempStart = _startDate ?? DateTime(now.year, now.month, 1);
    DateTime tempEnd = _endDate ?? DateTime(now.year, now.month, now.day);
    String tempPreset = _dateRangePreset;
    bool isSelectingStart = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildQuickPresetChip(String label, VoidCallback onSelected) {
              final isSelected = tempPreset == label;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1D4ED8),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF1E293B)),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: BorderSide(color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1)),
                  onSelected: (_) => onSelected(),
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dialog Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.date_range_rounded, color: Color(0xFF1D4ED8), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Select Date Range',
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Date Pickers indicators (From / To)
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setDialogState(() => isSelectingStart = true),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelectingStart ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelectingStart ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                                      width: isSelectingStart ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('FROM DATE', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(tempStart),
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setDialogState(() => isSelectingStart = false),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !isSelectingStart ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: !isSelectingStart ? const Color(0xFF1D4ED8) : const Color(0xFFCBD5E1),
                                      width: !isSelectingStart ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('TO DATE', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('dd MMM yyyy').format(tempEnd),
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Calendar Picker
                        Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF1D4ED8),
                              onPrimary: Colors.white,
                              onSurface: Color(0xFF0F172A),
                            ),
                          ),
                          child: CalendarDatePicker(
                            initialDate: isSelectingStart ? tempStart : tempEnd,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            onDateChanged: (picked) {
                              setDialogState(() {
                                tempPreset = 'Custom';
                                if (isSelectingStart) {
                                  tempStart = picked;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempEnd = tempStart;
                                  }
                                  isSelectingStart = false; // automatically switch to End date
                                } else {
                                  if (picked.isBefore(tempStart)) {
                                    tempStart = picked;
                                  } else {
                                    tempEnd = picked;
                                  }
                                }
                              });
                            },
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 10),

                        // Requirement 2: Quick Presets directly underneath the calendar!
                        Text(
                          'QUICK PRESETS',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              buildQuickPresetChip('Today', () {
                                final n = DateTime.now();
                                setDialogState(() {
                                  tempStart = DateTime(n.year, n.month, n.day);
                                  tempEnd = DateTime(n.year, n.month, n.day);
                                  tempPreset = 'Today';
                                });
                              }),
                              buildQuickPresetChip('Yesterday', () {
                                final n = DateTime.now();
                                final yest = n.subtract(const Duration(days: 1));
                                setDialogState(() {
                                  tempStart = DateTime(yest.year, yest.month, yest.day);
                                  tempEnd = DateTime(yest.year, yest.month, yest.day);
                                  tempPreset = 'Yesterday';
                                });
                              }),
                              buildQuickPresetChip('This Week', () {
                                final n = DateTime.now();
                                setDialogState(() {
                                  tempStart = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
                                  tempEnd = DateTime(n.year, n.month, n.day);
                                  tempPreset = 'This Week';
                                });
                              }),
                              buildQuickPresetChip('This Month', () {
                                final n = DateTime.now();
                                setDialogState(() {
                                  tempStart = DateTime(n.year, n.month, 1);
                                  tempEnd = DateTime(n.year, n.month, n.day);
                                  tempPreset = 'This Month';
                                });
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D4ED8),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                elevation: 1,
                              ),
                              onPressed: () {
                                setState(() {
                                  _startDate = tempStart;
                                  _endDate = tempEnd;
                                  _dateRangePreset = tempPreset;
                                });
                                Navigator.pop(ctx);
                                _loadReportData();
                              },
                              child: Text('Apply Range', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
    double cashInflow = 0.0;
    double cashOutflow = 0.0;
    double onlineInflow = 0.0;
    double onlineOutflow = 0.0;

    for (final exp in expenses) {
      final isCash = exp.paymentMode.toUpperCase() == 'CASH';
      if (exp.isCredit) {
        credit += exp.amount;
        if (isCash) {
          cashInflow += exp.amount;
        } else {
          onlineInflow += exp.amount;
        }
      } else {
        debit += exp.amount;
        if (isCash) {
          cashOutflow += exp.amount;
        } else {
          onlineOutflow += exp.amount;
        }
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
          'cashInflow': cashInflow,
          'cashOutflow': cashOutflow,
          'onlineInflow': onlineInflow,
          'onlineOutflow': onlineOutflow,
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
      final cashInflow = _summary['cashInflow'] ?? 0.0;
      final cashOutflow = _summary['cashOutflow'] ?? 0.0;
      final onlineInflow = _summary['onlineInflow'] ?? 0.0;
      final onlineOutflow = _summary['onlineOutflow'] ?? 0.0;

      PrinterService.instance.bluetooth
        ..printCustom(shopName.toUpperCase(), 2, 1)
        ..printCustom('EXPENSE & CASH REPORT', 1, 1)
        ..printCustom('Period: $_dateRangeLabel', 1, 0)
        ..printCustom('Generated: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}', 1, 0)
        ..printCustom('=' * 32, 1, 1)
        ..printCustom('Cash Inflow   (+): Rs.${cashInflow.toStringAsFixed(2)}', 1, 0)
        ..printCustom('Cash Outflow  (-): Rs.${cashOutflow.toStringAsFixed(2)}', 1, 0)
        ..printCustom('Online Inflow (+): Rs.${onlineInflow.toStringAsFixed(2)}', 1, 0)
        ..printCustom('Online Outflow(-): Rs.${onlineOutflow.toStringAsFixed(2)}', 1, 0)
        ..printCustom('-' * 32, 1, 1)
        ..printCustom('Total Credit  (+): Rs.${credit.toStringAsFixed(2)}', 1, 0)
        ..printCustom('Total Debit   (-): Rs.${debit.toStringAsFixed(2)}', 1, 0)
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
    final debit = _summary['debit'] ?? 0.0;
    final net = _summary['net'] ?? 0.0;
    final cashInflow = _summary['cashInflow'] ?? 0.0;
    final cashOutflow = _summary['cashOutflow'] ?? 0.0;
    final onlineInflow = _summary['onlineInflow'] ?? 0.0;
    final onlineOutflow = _summary['onlineOutflow'] ?? 0.0;

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

              // Financial Summary Block (Cash Inflow, Cash Outflow, Online Inflow, Online Outflow & Net)
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('CASH INFLOW', style: const pw.TextStyle(fontSize: 9, color: PdfColors.green800)),
                            pw.SizedBox(height: 3),
                            pw.Text('+ Rs. ${cashInflow.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.green800)),
                          ],
                        ),
                        pw.Container(height: 24, width: 1, color: PdfColors.grey300),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('CASH OUTFLOW', style: const pw.TextStyle(fontSize: 9, color: PdfColors.red800)),
                            pw.SizedBox(height: 3),
                            pw.Text('- Rs. ${cashOutflow.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.red800)),
                          ],
                        ),
                        pw.Container(height: 24, width: 1, color: PdfColors.grey300),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('ONLINE INFLOW', style: const pw.TextStyle(fontSize: 9, color: PdfColors.teal800)),
                            pw.SizedBox(height: 3),
                            pw.Text('+ Rs. ${onlineInflow.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.teal800)),
                          ],
                        ),
                        pw.Container(height: 24, width: 1, color: PdfColors.grey300),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text('ONLINE OUTFLOW', style: const pw.TextStyle(fontSize: 9, color: PdfColors.orange800)),
                            pw.SizedBox(height: 3),
                            pw.Text('- Rs. ${onlineOutflow.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.orange800)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(thickness: 0.8, color: PdfColors.grey300),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL NET BALANCE:', style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                        pw.Text(
                          '${net >= 0 ? '+' : ''} Rs. ${net.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: net >= 0 ? PdfColors.green800 : PdfColors.red800),
                        ),
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
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Expense & Cashflow Report',
        subtitle: 'Financial & Cash Flow Report',
        icon: Icons.bar_chart_rounded,
        actions: [
          IconButton(
            tooltip: 'All Itemized Transactions',
            icon: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF111111)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StandaloneItemizedTransactionsScreen(
                    initialStartDate: _startDate,
                    initialEndDate: _endDate,
                    initialPreset: _dateRangePreset,
                    initialCategoryId: _selectedCategoryId,
                    initialType: _selectedType,
                  ),
                ),
              );
            },
          ),
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

                              // 3. Itemized Transactions Action Button Card (Opens dedicated transactions screen)
                              _buildItemizedTransactionsActionCard(),
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

  /// Top Filter Controls Header (No white background strip - sits directly on gradient)
  Widget _buildFilterControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Single Date Range Dropdown with Icon and Label directly on front
          _buildDateRangeDropdown(),
          const SizedBox(height: 8),

          // 2. Filter Row: Category Dropdown & Type Dropdown (Properly styled & responsive)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildCategoryDropdown(),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildTypeDropdown(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 1. Single Date Range Dropdown
  Widget _buildDateRangeDropdown() {
    final String displayLabel = _dateRangePreset == 'Custom'
        ? 'Custom Range: $_dateRangeLabel'
        : '$_dateRangePreset ($_dateRangeLabel)';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
                  const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayLabel,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
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
                  Text('Today', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'Yesterday',
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text('Yesterday', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'This Week',
              child: Row(
                children: [
                  const Icon(Icons.calendar_view_week_rounded, size: 16, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Text('This Week', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'This Month',
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Text('This Month', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
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
                      'Custom Range (Pick Dates...)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (val) {
            if (val == null) return;
            if (val == 'Custom') {
              _pickCustomRangeWithPresets();
            } else {
              _applyPresetRange(val);
            }
          },
        ),
      ),
    );
  }

  /// 2. Category Filter Dropdown (Clean, spacious & responsive)
  Widget _buildCategoryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
              // 'ALL' item
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'All Categories',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              ..._categories.map((c) {
                return Row(
                  children: [
                    Icon(c.icon, size: 16, color: c.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.name,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }),
            ];
          },
          items: [
            DropdownMenuItem(
              value: 'VIEW_ALL_BREAKDOWN',
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
                        'View All Breakdown (EXPENSE BREAKDOWN BY CATEGORY)',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1D4ED8)),
                  ],
                ),
              ),
            ),
            DropdownMenuItem(
              value: 'ALL',
              child: Row(
                children: [
                  const Icon(Icons.category_outlined, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All Categories (${_categories.length})',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedCategoryId == 'ALL')
                    const Icon(Icons.check, size: 16, color: Color(0xFF1D4ED8)),
                ],
              ),
            ),
            ..._categories.map((c) {
              final isSelected = c.id == _selectedCategoryId;
              return DropdownMenuItem(
                value: c.id,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(c.icon, size: 14, color: c.color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.name,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check, size: 16, color: Color(0xFF1D4ED8)),
                  ],
                ),
              );
            }),
          ],
          onChanged: (val) {
            if (val == 'VIEW_ALL_BREAKDOWN') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StandaloneCategoryBreakdownScreen(
                    initialStartDate: _startDate,
                    initialEndDate: _endDate,
                    initialPreset: _dateRangePreset,
                  ),
                ),
              );
            } else if (val != null) {
              setState(() => _selectedCategoryId = val);
              _loadReportData();
            }
          },
        ),
      ),
    );
  }

  /// 3. Type Filter Dropdown (Clean, spacious & responsive)
  Widget _buildTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
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
          selectedItemBuilder: (context) {
            return [
              // 'ALL' item
              Row(
                children: [
                  const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'All Types',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // 'CREDIT' item
              Row(
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 16, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Credit (Inflow)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2E7D32)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // 'DEBIT' item
              Row(
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 16, color: Color(0xFFC62828)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Debit (Outflow)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFC62828)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ];
          },
          items: [
            DropdownMenuItem(
              value: 'ALL',
              child: Row(
                children: [
                  const Icon(Icons.swap_vert_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All Types',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedType == 'ALL')
                    const Icon(Icons.check, size: 16, color: Color(0xFF1D4ED8)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'CREDIT',
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF2E7D32)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Credit (Inflow)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedType == 'CREDIT')
                    const Icon(Icons.check, size: 16, color: Color(0xFF2E7D32)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'DEBIT',
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFC62828)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Debit (Outflow)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFC62828)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedType == 'DEBIT')
                    const Icon(Icons.check, size: 16, color: Color(0xFFC62828)),
                ],
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedType = val);
              _loadReportData();
            }
          },
        ),
      ),
    );
  }

  /// 1. Metric Summary Cards (Cash Inflow, Cash Outflow, Online Inflow, Online Outflow & Net Balance)
  Widget _buildSummaryCards() {
    final cashInflow = _summary['cashInflow'] ?? 0.0;
    final cashOutflow = _summary['cashOutflow'] ?? 0.0;
    final onlineInflow = _summary['onlineInflow'] ?? 0.0;
    final onlineOutflow = _summary['onlineOutflow'] ?? 0.0;
    final net = _summary['net'] ?? 0.0;
    final netCash = cashInflow - cashOutflow;
    final netOnline = onlineInflow - onlineOutflow;

    final cashInflowCount = _filteredExpenses.where((e) => e.isCredit && e.paymentMode.toUpperCase() == 'CASH').length;
    final cashOutflowCount = _filteredExpenses.where((e) => e.isDebit && e.paymentMode.toUpperCase() == 'CASH').length;
    final onlineInflowCount = _filteredExpenses.where((e) => e.isCredit && e.paymentMode.toUpperCase() != 'CASH').length;
    final onlineOutflowCount = _filteredExpenses.where((e) => e.isDebit && e.paymentMode.toUpperCase() != 'CASH').length;

    return Column(
      children: [
        // Row 1: Cash Inflow & Cash Outflow
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Cash Inflow',
                amount: cashInflow,
                count: cashInflowCount,
                isPositive: true,
                icon: Icons.payments_rounded,
                accentColor: const Color(0xFF15803D),
                borderColor: const Color(0xFFBBF7D0),
                badgeBgColor: const Color(0xFFDCFCE7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                title: 'Cash Outflow',
                amount: cashOutflow,
                count: cashOutflowCount,
                isPositive: false,
                icon: Icons.payments_rounded,
                accentColor: const Color(0xFFB91C1C),
                borderColor: const Color(0xFFFECDD3),
                badgeBgColor: const Color(0xFFFFE4E6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Online Inflow & Online Outflow
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Online Inflow',
                amount: onlineInflow,
                count: onlineInflowCount,
                isPositive: true,
                icon: Icons.account_balance_wallet_rounded,
                accentColor: const Color(0xFF0F766E),
                borderColor: const Color(0xFF99F6E4),
                badgeBgColor: const Color(0xFFCCFBF1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                title: 'Online Outflow',
                amount: onlineOutflow,
                count: onlineOutflowCount,
                isPositive: false,
                icon: Icons.account_balance_wallet_rounded,
                accentColor: const Color(0xFFC2410C),
                borderColor: const Color(0xFFFED7AA),
                badgeBgColor: const Color(0xFFFFEDD5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 3: Total Net Balance Card
        _buildNetBalanceCard(net, netCash, netOnline),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required int count,
    required bool isPositive,
    required IconData icon,
    required Color accentColor,
    required Color borderColor,
    required Color badgeBgColor,
  }) {
    final prefix = isPositive ? '+ ' : '- ';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 13, color: accentColor),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count txns',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$prefix\u20B9${amount.toStringAsFixed(2)}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetBalanceCard(double totalNet, double netCash, double netOnline) {
    final isSurplus = totalNet >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_rounded, size: 16, color: Color(0xFF334155)),
                  const SizedBox(width: 6),
                  Text(
                    'Net Balance',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${isSurplus ? '+' : ''}\u20B9${totalNet.toStringAsFixed(2)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isSurplus ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cash Net: ${netCash >= 0 ? '+' : ''}\u20B9${netCash.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: netCash >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                ),
              ),
              Text(
                'Online Net: ${netOnline >= 0 ? '+' : ''}\u20B9${netOnline.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: netOnline >= 0 ? const Color(0xFF0F766E) : const Color(0xFFC2410C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Category Breakdown Card
  Widget _buildCategoryBreakdownCard() {
    final debit = _summary['debit'] ?? 0.0;
    final sortedEntries = _categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayedEntries = sortedEntries.take(4).toList();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              if (sortedEntries.length > 4)
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StandaloneCategoryBreakdownScreen(
                          initialStartDate: _startDate,
                          initialEndDate: _endDate,
                          initialPreset: _dateRangePreset,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'View All (${sortedEntries.length})',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...displayedEntries.map((e) {
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
          if (sortedEntries.length > 4 || sortedEntries.isNotEmpty) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StandaloneCategoryBreakdownScreen(
                      initialStartDate: _startDate,
                      initialEndDate: _endDate,
                      initialPreset: _dateRangePreset,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pie_chart_rounded, size: 15, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 6),
                    Text(
                      'View All Categories Breakdown (${sortedEntries.length})',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1D4ED8)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 3. Dedicated Itemized Transactions Button Card (Opens All Itemized Transactions Screen)
  Widget _buildItemizedTransactionsActionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StandaloneItemizedTransactionsScreen(
                  initialStartDate: _startDate,
                  initialEndDate: _endDate,
                  initialPreset: _dateRangePreset,
                  initialCategoryId: _selectedCategoryId,
                  initialType: _selectedType,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1D4ED8), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ITEMIZED TRANSACTIONS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D4ED8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_filteredExpenses.length}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap here to view all itemized transactions & details',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1D4ED8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
