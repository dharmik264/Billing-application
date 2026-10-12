import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/restaurant_api.dart';
import '../utils/bill_event_notifier.dart';
import '../widgets/custom_page_header.dart';
import '../utils/app_constants.dart';
import 'print_preview_screen.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final ApiCustomer customer;

  const CustomerLedgerScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _error;
  ApiCustomerLedger? _ledger;

  late TabController _tabController;

  static const _indigo = StitchColors.primary;
  static const _slate50 = StitchColors.background;
  static const _slate200 = StitchColors.border;
  static const _slate400 = StitchColors.textMuted;
  static const _slate600 = StitchColors.textSecondary;
  static const _slate700 = StitchColors.textSecondary;
  static const _slate900 = StitchColors.textPrimary;
  static const _green = StitchColors.successText;
  static const _red = StitchColors.dangerText;
  static const _amber = StitchColors.warningText;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    BillEventNotifier.billRefreshNotifier.addListener(_onBillChanged);
    _loadLedger();
  }

  @override
  void dispose() {
    BillEventNotifier.billRefreshNotifier.removeListener(_onBillChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onBillChanged() {
    if (mounted) {
      _loadLedger();
    }
  }

  Future<void> _loadLedger() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ledgerData = await RestaurantApi.instance.fetchCustomerLedger(widget.customer.id);
      if (!mounted) return;
      setState(() {
        _ledger = ledgerData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatAmount(double amount) {
    final absAmount = amount.abs();
    final formatted = (absAmount % 1 == 0)
        ? _currencyFormat.format(absAmount)
        : NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(absAmount);
    return amount < 0 ? '-$formatted' : formatted;
  }

  // ── Six Summary Cards Dynamic Calculations ──────────────────────
  double get _cashTotal {
    if (_ledger == null) return 0.0;
    double total = 0.0;
    for (final bill in _ledger!.bills) {
      final mode = bill.paymentMode.toLowerCase().trim();
      if (mode == 'cash') {
        total += bill.grandTotal;
      }
    }
    return total;
  }

  double get _onlineTotal {
    if (_ledger == null) return 0.0;
    double total = 0.0;
    for (final bill in _ledger!.bills) {
      final mode = bill.paymentMode.toLowerCase().trim();
      if (mode == 'online' || mode == 'upi' || mode == 'card' || mode == 'qr' || mode.contains('online') || mode.contains('upi')) {
        total += bill.grandTotal;
      }
    }
    return total;
  }

  double get _udharTotal {
    if (_ledger == null) return 0.0;
    double total = 0.0;
    for (final bill in _ledger!.bills) {
      final mode = bill.paymentMode.toLowerCase().trim();
      if (mode == 'udhar' || mode == 'credit') {
        total += bill.grandTotal;
      }
    }
    return total;
  }

  double get _totalBillAmount {
    if (_ledger == null) return 0.0;
    return _ledger!.summary.totalBilled;
  }

  double get _totalCreditAmount {
    if (_ledger == null) return 0.0;
    double total = 0.0;
    for (final p in _ledger!.payments) {
      final mode = p.paymentMode.toLowerCase().trim();
      if (p.tokenId == null && mode != 'm-debit' && mode != 'debit') {
        total += p.amount;
      }
    }
    return total;
  }

  double get _totalDebitAmount {
    if (_ledger == null) return 0.0;
    double total = 0.0;
    for (final p in _ledger!.payments) {
      final mode = p.paymentMode.toLowerCase().trim();
      if (p.tokenId == null && (mode == 'm-debit' || mode == 'debit')) {
        total += p.amount.abs();
      }
    }
    return total;
  }







  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _slate50,
      appBar: CustomAppBar(
        title: '${widget.customer.name}\'s Ledger',
        icon: Icons.account_balance_wallet_rounded,
        subtitle: widget.customer.mobileNumber,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _printA4Ledger,
              icon: const Icon(Icons.print_rounded, size: 14),
              label: const Text(
                'PRINT',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _slate600),
            onPressed: _loadLedger,
            tooltip: 'Refresh Ledger',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _indigo))
                : _error != null
                    ? _buildErrorState()
                    : _buildBody(),
          ),
        ),
      ),
    );
  }

  // ── Credit Dialog (Customer pays shop) ────────────────────────
  Future<void> _showCreditDialog() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? validationError;
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_downward_rounded, color: _green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('M-Credit Entry', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: _slate900)),
                        Text('Customer pays shop', style: GoogleFonts.inter(fontSize: 12, color: _slate600)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Amount (₹)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _slate700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _slate900),
                      onChanged: (_) => setDialogState(() => validationError = null),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _slate700),
                        hintText: '0',
                        errorText: validationError,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _green, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Note (Optional)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _slate700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Payment for March bills',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: _slate600, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : () async {
                    final amt = double.tryParse(amountCtrl.text.trim());
                    if (amt == null || amt <= 0) {
                      setDialogState(() => validationError = 'Enter a valid amount greater than zero.');
                      return;
                    }
                    final nav = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    setDialogState(() => submitting = true);
                    try {
                      await RestaurantApi.instance.recordCustomerCredit(
                        customerId: widget.customer.id,
                        amount: amt,
                        paymentMode: 'm-credit',
                        note: noteCtrl.text.trim(),
                      );
                      if (mounted) {
                        nav.pop();
                        messenger.showSnackBar(SnackBar(
                          content: Text('M-Credit of ${_formatAmount(amt)} recorded.'),
                          backgroundColor: _green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        _loadLedger();
                      }
                    } catch (e) {
                      setDialogState(() {
                        submitting = false;
                        validationError = e.toString().replaceAll('Exception: ', '');
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Save M-Credit', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Debit Dialog (Shop charges customer) ────────────────────────
  Future<void> _showDebitDialog() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? validationError;
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: _red, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('M-Debit Entry', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17, color: _slate900)),
                        Text('Shop charges customer', style: GoogleFonts.inter(fontSize: 12, color: _slate600)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Charge Amount (₹)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _slate700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _slate900),
                      onChanged: (_) => setDialogState(() => validationError = null),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _slate700),
                        hintText: '0',
                        errorText: validationError,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _red, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Reason / Note', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _slate700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Late fee, extra items...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: _slate600, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : () async {
                    final amt = double.tryParse(amountCtrl.text.trim());
                    if (amt == null || amt <= 0) {
                      setDialogState(() => validationError = 'Enter a valid amount greater than zero.');
                      return;
                    }
                    final nav = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    setDialogState(() => submitting = true);
                    try {
                      await RestaurantApi.instance.recordCustomerDebit(
                        customerId: widget.customer.id,
                        amount: amt,
                        note: noteCtrl.text.trim(),
                      );
                      if (mounted) {
                        nav.pop();
                        messenger.showSnackBar(SnackBar(
                          content: Text('M-Debit of ${_formatAmount(amt)} added to account.'),
                          backgroundColor: _red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        _loadLedger();
                      }
                    } catch (e) {
                      setDialogState(() {
                        submitting = false;
                        validationError = e.toString().replaceAll('Exception: ', '');
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Save M-Debit', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }





  Widget _buildBody() {
    final summary = _ledger!.summary;

    return RefreshIndicator(
      onRefresh: _loadLedger,
      color: _indigo,
      child: Column(
        children: [
          // Summary Header Cards
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _slate200, width: 1)),
            ),
            child: _buildThreeColumnSummaryCards(summary),
          ),

          // Tabs Header for Bills & Payments
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: _indigo,
              unselectedLabelColor: _slate600,
              indicatorColor: _indigo,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: [
                Tab(text: 'Billing (${_ledger!.bills.length})'),
                Tab(text: 'Payment (${_ledger!.payments.length})'),
                Tab(text: 'Ledger (${_computeLedgerRows().length})'),
              ],
            ),
          ),

          // Tab Views Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBillsTable(),
                _buildPaymentsTable(),
                _buildLedgerReportTable(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeColumnSummaryCards(ApiCustomerLedgerSummary summary) {
    final totalCredit = _cashTotal + _onlineTotal + _totalCreditAmount;
    final totalDebit = _totalBillAmount + _totalDebitAmount;
    final netDue = summary.netDue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── First Column: Bill Cash, Bill Online, M Credit ────────
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(
                title: 'Bill Cash',
                value: _formatAmount(_cashTotal),
                color: const Color(0xFF16A34A),
                bgColor: const Color(0xFFF0FDF4),
                icon: Icons.payments_rounded,
              ),
              const SizedBox(height: 8),
              _buildMetricCard(
                title: 'Bill Online',
                value: _formatAmount(_onlineTotal),
                color: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
                icon: Icons.qr_code_2_rounded,
              ),
              const SizedBox(height: 8),
              _buildMetricCard(
                title: 'M Credit',
                value: _formatAmount(_totalCreditAmount),
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                icon: Icons.arrow_downward_rounded,
                onTap: _showCreditDialog,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // ── Second Column: Bill Udhar, Bill Total, M Debit ────────
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(
                title: 'Bill Udhar',
                value: _formatAmount(_udharTotal),
                color: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
                icon: Icons.pending_actions_rounded,
              ),
              const SizedBox(height: 8),
              _buildMetricCard(
                title: 'Bill Total',
                value: _formatAmount(_totalBillAmount),
                color: const Color(0xFF1F2937),
                bgColor: const Color(0xFFF3F4F6),
                icon: Icons.receipt_long_rounded,
              ),
              const SizedBox(height: 8),
              _buildMetricCard(
                title: 'M Debit',
                value: _formatAmount(_totalDebitAmount),
                color: const Color(0xFFDC2626),
                bgColor: const Color(0xFFFEF2F2),
                icon: Icons.arrow_upward_rounded,
                onTap: _showDebitDialog,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // ── Third Column: Total Credit, Total Debit, Net Due ──────
        Expanded(
          child: Column(
            children: [
              _buildMetricCard(
                title: 'Total Credit',
                value: _formatAmount(totalCredit),
                color: const Color(0xFF0D9488),
                bgColor: const Color(0xFFF0FDFA),
                icon: Icons.account_balance_rounded,
              ),
              const SizedBox(height: 8),
              _buildMetricCard(
                title: 'Total Debit',
                value: _formatAmount(totalDebit),
                color: const Color(0xFF9333EA),
                bgColor: const Color(0xFFFAF5FF),
                icon: Icons.calculate_rounded,
              ),
              const SizedBox(height: 8),
              _buildMetricCard(
                title: 'Net Due',
                value: _formatAmount(netDue),
                color: netDue > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                bgColor: netDue > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                icon: Icons.account_balance_wallet_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.add_circle_rounded, size: 14, color: color),
              ],
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _slate900,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: cardContent,
        ),
      );
    }
    return cardContent;
  }

  // ── Billing History Table ───────────────────────────────────────
  Widget _buildBillsTable() {
    final bills = _ledger!.bills;
    if (bills.isEmpty) {
      return _buildEmptyState('No bills found for this customer.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bills.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final bill = bills[i];
        final DateTime dateTime = DateTime.tryParse(bill.createdAt)?.toLocal() ?? DateTime.now();
        final dateStr = DateFormat('dd/MM/yyyy').format(dateTime);
        final timeStr = DateFormat('hh:mm a').format(dateTime);

        final double billTotal = bill.grandTotal;
        final double paidAmt = bill.isPaid ? billTotal : (bill.receivedAmount > 0 ? bill.receivedAmount : 0.0);
        final double dueAmt = bill.isPaid ? 0.0 : (billTotal > paidAmt ? (billTotal - paidAmt) : 0.0);
        final bool billPaid = bill.isPaid || dueAmt <= 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PrintPreviewScreen(
                    tokenNumber: bill.tokenNumber,
                    billNumber: bill.billNumber,
                    customerName: widget.customer.name,
                    customerPhone: widget.customer.mobileNumber,
                    paymentMode: bill.paymentMode,
                    items: bill.items.map((it) => ApiTokenItemDraft(
                      name: it.name,
                      code: it.code,
                      quantity: it.quantity,
                      rate: it.rate,
                    )).toList(),
                    subtotal: bill.grandTotal,
                    tax: 0.0,
                    grandTotal: bill.grandTotal,
                  ),
                ));
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _indigo.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Bill #${bill.billNumber}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _indigo,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Token #${bill.tokenNumber}',
                              style: GoogleFonts.inter(fontSize: 12, color: _slate600, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (bill.paymentMode.toLowerCase() == 'udhar' || bill.paymentMode.toLowerCase() == 'credit') ? _amber.withValues(alpha: 0.1) : (billPaid ? _green.withValues(alpha: 0.1) : _amber.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (bill.paymentMode.toLowerCase() == 'udhar' || bill.paymentMode.toLowerCase() == 'credit') ? 'UDHAR' : (billPaid ? 'PAID (${bill.paymentMode.toUpperCase()})' : 'DUE: ${_formatAmount(dueAmt)}'),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: (bill.paymentMode.toLowerCase() == 'udhar' || bill.paymentMode.toLowerCase() == 'credit') ? _amber : (billPaid ? _green : _amber),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: _slate400),
                            const SizedBox(width: 4),
                            Text(dateStr, style: GoogleFonts.inter(fontSize: 12, color: _slate600)),
                            const SizedBox(width: 10),
                            const Icon(Icons.access_time_rounded, size: 12, color: _slate400),
                            const SizedBox(width: 4),
                            Text(timeStr, style: GoogleFonts.inter(fontSize: 12, color: _slate600)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _tableMetric('Bill Amount', _formatAmount(billTotal), _slate900),
                        _tableMetric('Paid Amount', _formatAmount(paidAmt), _green),
                        _tableMetric('Due Amount', _formatAmount(dueAmt), dueAmt > 0 ? _red : _slate600, isBold: dueAmt > 0),
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
  }

  // ── Payment History Table ──────────────────────────────────────
  Widget _buildPaymentsTable() {
    final payments = _ledger!.payments;
    if (payments.isEmpty) {
      return _buildEmptyState('No payment transactions recorded yet.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final payment = payments[i];
        final DateTime dateTime = DateTime.tryParse(payment.createdAt)?.toLocal() ??
            DateTime.tryParse(payment.date)?.toLocal() ??
            DateTime.now();
        final dateStr = DateFormat('dd/MM/yyyy').format(dateTime);
        final timeStr = DateFormat('hh:mm a').format(dateTime);

        final isDebit = payment.paymentMode.toLowerCase() == 'm-debit' || payment.paymentMode.toLowerCase() == 'debit' || payment.amount < 0;
        final hasBillInfo = payment.billNumber.isNotEmpty || payment.tokenNumber.isNotEmpty;
        final custName = payment.customerName.isNotEmpty ? payment.customerName : widget.customer.name;

        String primaryRef;
        String secondaryRef;

        if (hasBillInfo) {
          final String billPart = payment.billNumber.isNotEmpty ? 'Bill #${payment.billNumber}' : '';
          final String tokenPart = payment.tokenNumber.isNotEmpty ? 'Token #${payment.tokenNumber}' : '';
          primaryRef = [billPart, tokenPart].where((s) => s.isNotEmpty).join(' • ');
          secondaryRef = 'Method: ${payment.paymentMode.toUpperCase()}';
        } else {
          primaryRef = custName;
          secondaryRef = payment.note.isNotEmpty
              ? payment.note
              : (isDebit ? 'M-Debit Transaction' : (payment.paymentMode.toLowerCase() == 'm-credit' ? 'M-Credit Transaction' : 'Credit Transaction'));
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _slate200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDebit ? _red.withValues(alpha: 0.1) : _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDebit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isDebit ? _red : _green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            primaryRef,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _slate900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isDebit ? '-${_formatAmount(payment.amount.abs())}' : _formatAmount(payment.amount),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: isDebit ? _red : _green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secondaryRef,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _indigo),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$dateStr, $timeStr',
                          style: GoogleFonts.inter(fontSize: 12, color: _slate600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _slate50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _slate200),
                          ),
                          child: Text(
                            payment.paymentMode.toUpperCase(),
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: _slate700),
                          ),
                        ),
                      ],
                    ),
                    if (hasBillInfo && payment.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        payment.note,
                        style: GoogleFonts.inter(fontSize: 11, color: _slate400, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── A4 Ledger Printing ─────────────────────────────────────────
  Future<void> _printA4Ledger() async {
    if (_ledger == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ledger data is loading... Please try again in a moment.')),
      );
      return;
    }

    final rows = _computeLedgerRows();
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions found in this customer ledger.')),
      );
      return;
    }

    try {
      final totalDebit = _totalBillAmount + _totalDebitAmount;
      final totalCredit = _cashTotal + _onlineTotal + _totalCreditAmount;
      final netDue = _ledger!.summary.netDue;

      ApiShopData? shop;
      try {
        shop = await RestaurantApi.instance.fetchShop();
      } catch (_) {}

      final pdf = pw.Document()
        ..addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
            header: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            shop != null && shop.name.isNotEmpty ? shop.name : 'BILLING APPLICATION',
                            style: const pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey900,
                            ),
                          ),
                        if (shop != null && shop.address != null && shop.address!.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(
                              shop.address!,
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                            ),
                          ),
                        if (shop != null && shop.phone != null && shop.phone!.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 1),
                            child: pw.Text(
                              'Phone: ${shop.phone!}',
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                            ),
                          ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blueGrey800,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'CUSTOMER LEDGER',
                            style: const pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Printed: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 6),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Customer Statement • Generated automatically',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) => [
            // Customer Info Box & Account Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CUSTOMER DETAILS',
                        style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        widget.customer.name,
                        style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                      ),
                      if (widget.customer.mobileNumber.isNotEmpty)
                        pw.Text(
                          'Mobile: ${widget.customer.mobileNumber}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                        ),
                      if (widget.customer.address.isNotEmpty)
                        pw.Text(
                          'Address: ${widget.customer.address}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                        ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      _pdfMetricBox('TOTAL DEBIT', 'Rs. ${totalDebit.toStringAsFixed(2)}', PdfColors.red800),
                      pw.SizedBox(width: 12),
                      _pdfMetricBox('TOTAL CREDIT', 'Rs. ${totalCredit.toStringAsFixed(2)}', PdfColors.green800),
                      pw.SizedBox(width: 12),
                      _pdfMetricBox(
                        'OUTSTANDING',
                        'Rs. ${netDue.abs().toStringAsFixed(2)} ${netDue > 0 ? "DUE" : (netDue < 0 ? "ADV" : "")}',
                        netDue > 0 ? PdfColors.red800 : (netDue < 0 ? PdfColors.green800 : PdfColors.black),
                        isHighlight: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Ledger Statement Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(5.2), // DETAILS
                1: pw.FlexColumnWidth(2.2), // CREDIT
                2: pw.FlexColumnWidth(2.2), // DEBIT
                3: pw.FlexColumnWidth(2.6), // OUTSTANDING AMOUNT
              },
              children: [
                // Table Header: DETAILS, CREDIT, DEBIT, OUTSTANDING AMOUNT
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    _pdfCell('DETAILS', isHeader: true),
                    _pdfCell('CREDIT', isHeader: true, align: pw.TextAlign.right),
                    _pdfCell('DEBIT', isHeader: true, align: pw.TextAlign.right),
                    _pdfCell('OUTSTANDING AMOUNT', isHeader: true, align: pw.TextAlign.right),
                  ],
                ),
                // Table Data Rows
                for (int i = 0; i < rows.length; i++)
                  _buildPdfTableRow(rows[i], i % 2 == 1),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Ledger_${widget.customer.name.replaceAll(' ', '_')}_A4',
        format: PdfPageFormat.a4,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print ledger: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static pw.Widget _pdfMetricBox(String label, String value, PdfColor color, {bool isHighlight = false}) {
    return pw.Container(
      padding: isHighlight
          ? const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const pw.EdgeInsets.all(2),
      decoration: isHighlight
          ? pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            )
          : null,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static pw.TableRow _buildPdfTableRow(_CustomerLedgerRow row, bool isAlt) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isAlt ? PdfColors.grey50 : PdfColors.white,
      ),
      children: [
        // DETAILS
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Text(
                      row.badgeText,
                      style: const pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Text(
                      row.title,
                      style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${row.dateStr} • ${row.timeStr}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              if (row.subtitle.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  row.subtitle,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                  maxLines: 2,
                ),
              ],
            ],
          ),
        ),

        // CREDIT
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            row.credit > 0 ? 'Rs. ${row.credit.toStringAsFixed(2)}' : '-',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: row.credit > 0 ? PdfColors.green800 : PdfColors.grey500,
            ),
          ),
        ),

        // DEBIT
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            row.debit > 0 ? 'Rs. ${row.debit.toStringAsFixed(2)}' : '-',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: row.debit > 0 ? PdfColors.red800 : PdfColors.grey500,
            ),
          ),
        ),

        // OUTSTANDING AMOUNT
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Rs. ${row.outstanding.abs().toStringAsFixed(2)}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: row.outstanding > 0
                      ? PdfColors.red800
                      : (row.outstanding < 0 ? PdfColors.green800 : PdfColors.black),
                ),
              ),
              if (row.outstanding != 0)
                pw.Text(
                  row.outstanding > 0 ? 'DUE' : 'ADV',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: row.outstanding > 0 ? PdfColors.red800 : PdfColors.green800,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }


  List<_CustomerLedgerRow> _computeLedgerRows() {
    if (_ledger == null) return [];
    final List<_CustomerLedgerRow> rows = [];

    // 1. Bills (Invoice Debits & Customer Payments on bill)
    for (final bill in _ledger!.bills) {
      final dt = DateTime.tryParse(bill.createdAt)?.toLocal() ?? DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy').format(dt);
      final timeStr = DateFormat('hh:mm a').format(dt);

      final double billTotal = bill.grandTotal;
      final pm = bill.paymentMode.toLowerCase().trim();
      final bool isUdhar = pm == 'udhar' || pm == 'credit';

      final double debit = billTotal;
      final double credit = isUdhar
          ? 0.0
          : (bill.isPaid ? billTotal : (bill.receivedAmount > 0 ? bill.receivedAmount : 0.0));

      final itemsText = bill.items.map((it) => '${it.name} x${it.quantity}').join(', ');
      final subtitle = itemsText.isNotEmpty ? itemsText : 'Invoice items';

      final String badgeText = isUdhar ? 'UDHAR' : (bill.isPaid ? 'PAID (${bill.paymentMode.toUpperCase()})' : 'BILL');
      final Color badgeBg = isUdhar
          ? const Color(0xFFFFFBEB)
          : (bill.isPaid ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF));
      final Color badgeFg = isUdhar
          ? const Color(0xFFD97706)
          : (bill.isPaid ? const Color(0xFF16A34A) : const Color(0xFF2563EB));

      rows.add(_CustomerLedgerRow(
        dateTime: dt,
        dateStr: dateStr,
        timeStr: timeStr,
        title: 'Bill #${bill.billNumber} • Token #${bill.tokenNumber}',
        subtitle: subtitle,
        badgeText: badgeText,
        badgeBg: badgeBg,
        badgeFg: badgeFg,
        debit: debit,
        credit: credit,
      ));
    }

    // 2. Standalone Manual Payments (M-Credit / M-Debit / Advance)
    for (final p in _ledger!.payments) {
      if (p.tokenId != null) continue; // Already represented in bill payment above

      final dt = DateTime.tryParse(p.createdAt)?.toLocal() ??
                 DateTime.tryParse(p.date)?.toLocal() ??
                 DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy').format(dt);
      final timeStr = DateFormat('hh:mm a').format(dt);

      final mode = p.paymentMode.toLowerCase().trim();
      final bool isDebit = mode == 'm-debit' || mode == 'debit' || p.amount < 0;

      final double debit = isDebit ? p.amount.abs() : 0.0;
      final double credit = !isDebit ? p.amount.abs() : 0.0;

      final String badgeText = isDebit ? 'M-DEBIT' : (mode == 'm-credit' ? 'M-CREDIT' : p.paymentMode.toUpperCase());
      final Color badgeBg = isDebit ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
      final Color badgeFg = isDebit ? const Color(0xFFDC2626) : const Color(0xFF059669);

      final String title = isDebit ? 'M-Debit Transaction' : 'Payment Received (${p.paymentMode.toUpperCase()})';
      final String subtitle = p.note.isNotEmpty
          ? p.note
          : (isDebit ? 'Manual Debit on account' : 'Payment received from customer');

      rows.add(_CustomerLedgerRow(
        dateTime: dt,
        dateStr: dateStr,
        timeStr: timeStr,
        title: title,
        subtitle: subtitle,
        badgeText: badgeText,
        badgeBg: badgeBg,
        badgeFg: badgeFg,
        debit: debit,
        credit: credit,
      ));
    }

    // Sort chronologically (oldest first) to compute running balance
    rows.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    double runningBalance = 0.0;
    for (final row in rows) {
      runningBalance += (row.debit - row.credit);
      row.outstanding = runningBalance;
    }

    // Return newest to oldest for display
    return rows.reversed.toList();
  }

  Widget _buildLedgerReportTable({ScrollController? scrollController}) {
    final rows = _computeLedgerRows();
    if (rows.isEmpty) {
      return _buildEmptyState('No transactions found in customer ledger.');
    }

    return Column(
      children: [
        // Column Header: DETAILS | CREDIT | DEBIT | OUTSTANDING AMOUNT
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9),
            border: Border(bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'DETAILS',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'CREDIT',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'DEBIT',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFDC2626),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'OUTSTANDING AMOUNT',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows List
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (ctx, i) {
              final row = rows[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                color: i % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // DETAILS Column
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: row.badgeBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  row.badgeText,
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: row.badgeFg,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  row.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 10, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 3),
                              Text(
                                '${row.dateStr} • ${row.timeStr}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (row.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              row.subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF334155),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // CREDIT Column
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.credit > 0 ? _formatAmount(row.credit) : '₹0.00',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: row.credit > 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),

                    // DEBIT Column
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.debit > 0 ? _formatAmount(row.debit) : '₹0.00',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: row.debit > 0 ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),

                    // OUTSTANDING AMOUNT Column
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatAmount(row.outstanding),
                            textAlign: TextAlign.right,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: row.outstanding > 0
                                  ? const Color(0xFFDC2626)
                                  : (row.outstanding < 0 ? const Color(0xFF16A34A) : const Color(0xFF0F172A)),
                            ),
                          ),
                          if (row.outstanding != 0)
                            Text(
                              row.outstanding > 0 ? 'DUE' : 'ADVANCE',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: row.outstanding > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tableMetric(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _slate400, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: isBold ? FontWeight.w800 : FontWeight.w700)),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: _slate400.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              msg,
              style: GoogleFonts.inter(fontSize: 14, color: _slate600, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: _red),
            const SizedBox(height: 16),
            Text(
              'Failed to load customer ledger',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _slate900),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: GoogleFonts.inter(fontSize: 12, color: _slate600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadLedger,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerLedgerRow {
  final DateTime dateTime;
  final String dateStr;
  final String timeStr;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeBg;
  final Color badgeFg;
  final double debit;
  final double credit;
  double outstanding = 0.0;

  _CustomerLedgerRow({
    required this.dateTime,
    required this.dateStr,
    required this.timeStr,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeBg,
    required this.badgeFg,
    required this.debit,
    required this.credit,
  });
}
