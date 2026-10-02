import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/restaurant_api.dart';
import '../widgets/custom_page_header.dart';
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

  static const _indigo = Color(0xFF4F46E5);
  static const _slate50 = Color(0xFFF8FAFC);
  static const _slate200 = Color(0xFFE2E8F0);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate600 = Color(0xFF475569);
  static const _slate700 = Color(0xFF334155);
  static const _slate900 = Color(0xFF0F172A);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _amber = Color(0xFFF59E0B);

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLedger();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    if (amount % 1 == 0) {
      return _currencyFormat.format(amount);
    }
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(amount);
  }

  // ── Pay Due Dialog ─────────────────────────────────────────────
  Future<void> _showPayDueDialog() async {
    if (_ledger == null) return;
    final summary = _ledger!.summary;
    if (summary.netDue <= 0) return;

    final amountCtrl = TextEditingController();
    String selectedMode = 'CASH';
    String? validationError;
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.payments_rounded, color: _green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pay Due Amount',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: _slate900),
                        ),
                        Text(
                          widget.customer.name,
                          style: GoogleFonts.inter(fontSize: 12, color: _slate600),
                        ),
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
                    // Summary Box inside Dialog
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _slate50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _slate200),
                      ),
                      child: Column(
                        children: [
                          _dialogSummaryRow('Total Billed', _formatAmount(summary.totalBilled), _slate700),
                          const SizedBox(height: 6),
                          _dialogSummaryRow('Already Paid', _formatAmount(summary.totalPaid), _green),
                          const Divider(height: 16),
                          _dialogSummaryRow('Outstanding Due', _formatAmount(summary.netDue), _red, isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Enter Payment Amount',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _slate900),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _slate900),
                      onChanged: (val) {
                        setDialogState(() {
                          validationError = null;
                        });
                      },
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _slate700),
                        hintText: 'Enter amount...',
                        errorText: validationError,
                        errorMaxLines: 2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _indigo, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment Mode',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _slate700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _modeChip('Cash', 'CASH', selectedMode, (m) => setDialogState(() => selectedMode = m)),
                        const SizedBox(width: 8),
                        _modeChip('UPI', 'UPI', selectedMode, (m) => setDialogState(() => selectedMode = m)),
                        const SizedBox(width: 8),
                        _modeChip('Card', 'CARD', selectedMode, (m) => setDialogState(() => selectedMode = m)),
                      ],
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
                  onPressed: submitting
                      ? null
                      : () async {
                          final text = amountCtrl.text.trim();
                          if (text.isEmpty) {
                            setDialogState(() {
                              validationError = 'Please enter a payment amount.';
                            });
                            return;
                          }
                          final amt = double.tryParse(text);
                          if (amt == null || amt <= 0) {
                            setDialogState(() {
                              validationError = 'Amount must be greater than zero.';
                            });
                            return;
                          }
                          if (amt > summary.netDue) {
                            setDialogState(() {
                              validationError = 'Payment cannot exceed the outstanding amount of ${_formatAmount(summary.netDue)}.';
                            });
                            return;
                          }

                          final nav = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          setDialogState(() => submitting = true);
                          try {
                            await RestaurantApi.instance.payCustomerDue(
                              customerId: widget.customer.id,
                              amount: amt,
                              paymentMode: selectedMode,
                            );
                            if (mounted) {
                              nav.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Payment of ${_formatAmount(amt)} recorded successfully.'),
                                  backgroundColor: _green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
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
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text('Pay', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _modeChip(String label, String value, String selected, Function(String) onSelect) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _indigo.withValues(alpha: 0.12) : _slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _indigo : _slate200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _indigo : _slate700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogSummaryRow(String label, String value, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: _slate600,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _slate600),
            onPressed: _loadLedger,
            tooltip: 'Refresh Ledger',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _error != null
              ? _buildErrorState()
              : _buildBody(),
    );
  }

  // ── Jama Payment Dialog ────────────────────────────────────────
  Future<void> _showJamaDialog() async {
    final amountCtrl = TextEditingController();
    String selectedMode = 'CASH';
    String? validationError;
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: _green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jama Payment (\u0AA8\u0ABE\u0AA3\u0ABE\u0A82 \u0A9C\u0AAE\u0ABE)',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: _slate900),
                        ),
                        Text(
                          widget.customer.name,
                          style: GoogleFonts.inter(fontSize: 12, color: _slate600),
                        ),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.customer.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _slate900)),
                          const SizedBox(height: 2),
                          Text('Phone: ${widget.customer.mobileNumber}', style: GoogleFonts.inter(fontSize: 12, color: _slate600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Jama Amount (\u20B9 \u0A9C\u0AAE\u0ABE \u0AB0\u0A95\u0AAE)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _slate700)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                      onChanged: (_) {
                        setDialogState(() => validationError = null);
                      },
                      decoration: InputDecoration(
                        prefixText: '\u20B9 ',
                        hintText: 'Enter amount to credit...',
                        errorText: validationError,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _green, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Payment Mode (\u0A9A\u0AC2\u0A95\u0AB5\u0AA3\u0AC0 \u0AAE\u0ABE\u0AA1)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: _slate700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _modeChip('Cash', 'CASH', selectedMode, (m) => setDialogState(() => selectedMode = m)),
                        const SizedBox(width: 8),
                        _modeChip('UPI', 'ONLINE', selectedMode, (m) => setDialogState(() => selectedMode = m)),
                        const SizedBox(width: 8),
                        _modeChip('Card', 'CARD', selectedMode, (m) => setDialogState(() => selectedMode = m)),
                      ],
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
                    final text = amountCtrl.text.trim();
                    final amt = double.tryParse(text);
                    if (amt == null || amt <= 0) {
                      setDialogState(() {
                        validationError = 'Please enter a valid amount greater than zero.';
                      });
                      return;
                    }
                    final nav = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    setDialogState(() => submitting = true);
                    try {
                      final response = await RestaurantApi.instance.recordCustomerJama(
                        customerPhone: widget.customer.mobileNumber,
                        amount: amt,
                        paymentMode: selectedMode,
                        customerName: widget.customer.name,
                      );
                      if (mounted) {
                        nav.pop();
                        final int updatedCount = (response['updated_tokens_count'] as num?)?.toInt() ?? 0;
                        final double unused = (response['remaining_unused'] as num?)?.toDouble() ?? 0.0;
                        final double applied = (response['amount_applied'] as num?)?.toDouble() ?? 0.0;
                        
                        String msg = 'Jama of ${_formatAmount(amt)} recorded successfully for ${widget.customer.name}.';
                        Color msgBg = _green;
                        if (updatedCount == 0) {
                          msg = 'Jama recorded (${_formatAmount(amt)}). Note: No pending unpaid bills found for ${widget.customer.name}.';
                          msgBg = _indigo;
                        } else if (unused > 0) {
                          msg = '${_formatAmount(applied)} applied to bills. ${_formatAmount(unused)} registered as credit balance.';
                          msgBg = _amber;
                        }

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: msgBg,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Submit Jama (\u20B9 \u0A9C\u0AAE\u0ABE)', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerProfileCard(bool isPaidInFull, double netDue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _slate900.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _slate200),
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
                  gradient: const LinearGradient(
                    colors: [_indigo, Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    widget.customer.name.isNotEmpty ? widget.customer.name[0].toUpperCase() : 'C',
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.customer.name,
                            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: _slate900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: widget.customer.isActive ? _green.withValues(alpha: 0.12) : _slate200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.customer.isActive ? 'Active' : 'Inactive',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.customer.isActive ? _green : _slate600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: _slate600),
                        const SizedBox(width: 4),
                        Text(widget.customer.mobileNumber, style: GoogleFonts.inter(fontSize: 13, color: _slate700, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.customer.address.isNotEmpty || widget.customer.gstNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (widget.customer.address.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: _slate400),
                      const SizedBox(width: 3),
                      Text(widget.customer.address, style: GoogleFonts.inter(fontSize: 12, color: _slate600)),
                    ],
                  ),
                if (widget.customer.gstNumber.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 13, color: _slate400),
                      const SizedBox(width: 3),
                      Text('GST: ${widget.customer.gstNumber}', style: GoogleFonts.inter(fontSize: 12, color: _slate600)),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: _slate200),
          const SizedBox(height: 14),
          // Actions Row: Pay Due & Jama Payment
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: isPaidInFull ? null : _showPayDueDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPaidInFull ? _slate200 : _indigo,
                      foregroundColor: isPaidInFull ? _slate400 : Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      isPaidInFull ? Icons.check_circle_outline_rounded : Icons.payments_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isPaidInFull ? 'Paid in Full' : 'Pay Due (${_formatAmount(netDue)})',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _showJamaDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                    label: Text(
                      'Jama (\u20B9 \u0A9C\u0AAE\u0ABE)',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
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

  Widget _buildBody() {
    final summary = _ledger!.summary;
    final isPaidInFull = summary.netDue <= 0;

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
            child: Column(
              children: [
                // Customer Profile Card with Pay Due & Jama Options
                _buildCustomerProfileCard(isPaidInFull, summary.netDue),

                // 4 Financial Metric Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'TOTAL BILLED',
                        value: _formatAmount(summary.totalBilled),
                        color: _indigo,
                        bgColor: _indigo.withValues(alpha: 0.08),
                        icon: Icons.receipt_long_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'TOTAL PAID',
                        value: _formatAmount(summary.totalPaid),
                        color: _green,
                        bgColor: _green.withValues(alpha: 0.08),
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'NET DUE',
                        value: _formatAmount(summary.netDue),
                        color: isPaidInFull ? _slate600 : _red,
                        bgColor: isPaidInFull ? _slate50 : _red.withValues(alpha: 0.08),
                        icon: Icons.pending_actions_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatusCard(summary.paymentStatus, isPaidInFull),
                    ),
                  ],
                ),
              ],
            ),
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
                Tab(text: 'Billing History (${_ledger!.bills.length})'),
                Tab(text: 'Payment History (${_ledger!.payments.length})'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _slate900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String statusText, bool isPaidInFull) {
    final statusColor = isPaidInFull ? _green : _red;
    final bgColor = isPaidInFull ? _green.withValues(alpha: 0.08) : _red.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPaidInFull ? Icons.verified_rounded : Icons.warning_amber_rounded,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Text(
                'STATUS',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusText.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: statusColor,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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

        final double dueAmt = bill.balanceDue;
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
                            color: billPaid ? _green.withValues(alpha: 0.1) : _amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            billPaid ? 'PAID' : 'DUE',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: billPaid ? _green : _amber,
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
                        _tableMetric('Bill Amount', _formatAmount(bill.grandTotal), _slate900),
                        _tableMetric('Paid Amount', _formatAmount(bill.receivedAmount > 0 ? bill.receivedAmount : (bill.isPaid ? bill.grandTotal : 0.0)), _green),
                        _tableMetric('Remaining', _formatAmount(dueAmt), dueAmt > 0 ? _red : _slate600, isBold: dueAmt > 0),
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
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_downward_rounded, color: _green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          payment.paymentNumber.isNotEmpty ? 'Payment #${payment.paymentNumber}' : 'Payment #${payment.id}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _slate900),
                        ),
                        Text(
                          _formatAmount(payment.amount),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: _green),
                        ),
                      ],
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
                    if (payment.note.isNotEmpty) ...[
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
