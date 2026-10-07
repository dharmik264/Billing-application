import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/restaurant_api.dart';
import '../utils/app_constants.dart';
import '../widgets/custom_page_header.dart';
import 'print_preview_screen.dart';
import 'token_generation_screen.dart';
import '../utils/bill_event_notifier.dart';

class AllTokensScreen extends StatefulWidget {
  const AllTokensScreen({super.key});

  @override
  State<AllTokensScreen> createState() => _AllTokensScreenState();
}

class _AllTokensScreenState extends State<AllTokensScreen> {
  List<ApiToken> _tokens = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTokens();
    BillEventNotifier.billRefreshNotifier.addListener(_onBillChanged);
  }

  void _onBillChanged() {
    if (mounted) {
      _loadTokens();
    }
  }

  @override
  void dispose() {
    BillEventNotifier.billRefreshNotifier.removeListener(_onBillChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTokens() async {
    try {
      final tokens = await RestaurantApi.instance.fetchTokens();
      if (!mounted) return;
      setState(() {
        _tokens = tokens;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load tokens. Check backend connection.';
        _loading = false;
      });
    }
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString().substring(2);

      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final suffix = dt.hour >= 12 ? 'PM' : 'AM';

      return '$day/$month/$year, $hour:$minute $suffix';
    } catch (_) {
      return raw;
    }
  }

  void _openPrintPreview(ApiToken token) {
    final subtotal = token.items.fold(0.0, (sum, item) => sum + item.subtotal);
    final tax = token.grandTotal - subtotal;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          tokenNumber: token.tokenNumber,
          billNumber: token.billNumber,
          customerName: token.customerName.isNotEmpty ? token.customerName : null,
          customerPhone: token.customerPhone.isNotEmpty ? token.customerPhone : null,
          customerAddress: token.customerAddress.isNotEmpty ? token.customerAddress : null,
          customerGstNumber: token.customerGstNumber.isNotEmpty ? token.customerGstNumber : null,
          paymentMode: token.paymentMode,
          items: token.items
              .map((e) => ApiTokenItemDraft(
                    id: e.id,
                    name: e.name,
                    code: e.code,
                    rate: e.rate,
                    quantity: e.quantity,
                  ))
              .toList(),
          subtotal: subtotal,
          tax: tax > 0 ? tax : 0.0,
          grandTotal: token.grandTotal,
        ),
      ),
    );
  }

  List<ApiToken> get _filteredTokens {
    if (_searchQuery.isEmpty) return _tokens;
    final q = _searchQuery.toLowerCase();
    return _tokens.where((t) {
      return t.tokenNumber.toLowerCase().contains(q) ||
          t.billNumber.toLowerCase().contains(q) ||
          t.customerName.toLowerCase().contains(q) ||
          t.customerPhone.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StitchColors.background,
      appBar: CustomAppBar(
        title: 'Token & Bill History',
        icon: Icons.history_rounded,
        subtitle: '${_tokens.length} total bills',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: StitchColors.textSecondary),
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadTokens();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          CustomSearchActionView(
            searchHint: 'Search by Token #, Bill #, Customer Name or Phone...',
            searchController: _searchController,
            onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
            onSearchClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: StitchColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: StitchColors.textDisabled),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: StitchTypography.body(color: StitchColors.textMuted)),
          ],
        ),
      );
    }

    final list = _filteredTokens;

    if (list.isEmpty) {
      return Center(
        child: Text('No matching tokens found.', style: StitchTypography.body(color: StitchColors.textMuted)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTokens,
      color: StitchColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final token = list[index];
          return _buildTokenCard(token);
        },
      ),
    );
  }

  Widget _buildTokenCard(ApiToken token) {
    Color statusBg;
    Color statusBorder;
    Color statusText;
    String statusLabel = token.status.toUpperCase();

    if (statusLabel == 'COMPLETED') {
      statusBg = StitchColors.successBg;
      statusBorder = StitchColors.successBorder;
      statusText = StitchColors.successText;
    } else if (statusLabel == 'CANCELLED') {
      statusBg = StitchColors.dangerBg;
      statusBorder = StitchColors.dangerBorder;
      statusText = StitchColors.dangerText;
    } else {
      statusBg = StitchColors.infoBg;
      statusBorder = StitchColors.infoBorder;
      statusText = StitchColors.infoText;
    }

    final cName = token.customerName.trim();
    String displayTitle = cName.isNotEmpty ? cName : 'Walk-in Customer';
    if (token.billNumber.isNotEmpty) {
      displayTitle += ' (#${token.billNumber})';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: StitchDecorations.card(),
      child: InkWell(
        onTap: () => _openPrintPreview(token),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: StitchDecorations.badge(
                      backgroundColor: StitchColors.surfaceSubtle,
                      borderColor: StitchColors.border,
                    ),
                    child: Text(
                      'TOKEN ${token.tokenNumber}',
                      style: StitchTypography.monospace(color: StitchColors.primary, size: 11),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: StitchTypography.header(size: 13),
                    ),
                  ),
                  Text(
                    '\u20B9${token.grandTotal.toStringAsFixed(2)}',
                    style: StitchTypography.monospace(size: 14, weight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(token.createdAt),
                    style: StitchTypography.caption(),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _changePaymentMode(token),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: StitchDecorations.badge(
                            backgroundColor: StitchColors.surfaceSubtle,
                            borderColor: StitchColors.border,
                          ),
                          child: Row(
                            children: [
                              Text(
                                token.paymentMode.isNotEmpty ? token.paymentMode.toUpperCase() : 'CASH',
                                style: StitchTypography.caption(color: StitchColors.textSecondary).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_outlined, size: 12, color: StitchColors.textMuted),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: StitchDecorations.badge(
                          backgroundColor: statusBg,
                          borderColor: statusBorder,
                        ),
                        child: Text(
                          statusLabel,
                          style: StitchTypography.caption(color: statusText, size: 10).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!token.isPaid && token.status.toLowerCase() != 'cancelled') ...[
                    GestureDetector(
                      onTap: () => _showTokenJamaDialog(token),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: StitchDecorations.badge(
                          backgroundColor: StitchColors.successBg,
                          borderColor: StitchColors.successBorder,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 12, color: StitchColors.successText),
                            const SizedBox(width: 4),
                            Text('Jama (₹ જમા)', style: StitchTypography.caption(color: StitchColors.successText).copyWith(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  GestureDetector(
                    onTap: () => _editToken(token),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: StitchDecorations.badge(
                        backgroundColor: StitchColors.infoBg,
                        borderColor: StitchColors.infoBorder,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 12, color: StitchColors.infoText),
                          const SizedBox(width: 4),
                          Text('Edit', style: StitchTypography.caption(color: StitchColors.infoText).copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _deleteToken(token),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: StitchDecorations.badge(
                        backgroundColor: StitchColors.dangerBg,
                        borderColor: StitchColors.dangerBorder,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 12, color: StitchColors.dangerText),
                          const SizedBox(width: 4),
                          Text('Delete', style: StitchTypography.caption(color: StitchColors.dangerText).copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTokenJamaDialog(ApiToken token) async {
    final amountCtrl = TextEditingController(
      text: token.balanceDue > 0
          ? token.balanceDue.toStringAsFixed(2)
          : token.grandTotal.toStringAsFixed(2),
    );
    String selectedMode = 'CASH';
    bool submitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bill #${token.billNumber} Jama',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: const Color(0xFF0F172A)),
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
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (token.customerName.isNotEmpty)
                            Text(token.customerName,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: const Color(0xFF0F172A))),
                          Text(
                              'Bill Total: \u20B9${token.grandTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF475569))),
                          if (token.receivedAmount > 0)
                            Text(
                                'Already Paid: \u20B9${token.receivedAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF10B981))),
                          if (token.balanceDue > 0)
                            Text(
                                'Remaining Due: \u20B9${token.balanceDue.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Jama Amount (\u20B9 જમા રકમ)',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        prefixText: '\u20B9 ',
                        hintText: 'Enter amount...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF10B981), width: 2)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Payment Mode (ચૂકવણી મોડ)',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: const Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Cash'),
                            selected: selectedMode == 'CASH',
                            selectedColor:
                                const Color(0xFF10B981).withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() => selectedMode = 'CASH');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('UPI'),
                            selected: selectedMode == 'ONLINE',
                            selectedColor:
                                const Color(0xFF4F46E5).withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() => selectedMode = 'ONLINE');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Card'),
                            selected: selectedMode == 'CARD',
                            selectedColor: Colors.amber.withValues(alpha: 0.2),
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() => selectedMode = 'CARD');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      submitting ? null : () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: GoogleFonts.inter(color: const Color(0xFF475569))),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final text = amountCtrl.text.trim();
                          final amt = double.tryParse(text);
                          if (amt == null || amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please enter a valid amount greater than zero')),
                            );
                            return;
                          }
                          setDialogState(() => submitting = true);
                          try {
                            await RestaurantApi.instance.processPayment(
                              token.id,
                              selectedMode,
                              amount: amt,
                            );
                            if (context.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setDialogState(() => submitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Jama failed: $e'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Submit Jama (\u20B9 જમા)',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Jama recorded for Bill #${token.billNumber}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadTokens();
      }
    }
  }

  Future<void> _changePaymentMode(ApiToken token) async {
    final newMode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Payment Mode',
            style:
                GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Cash', style: GoogleFonts.inter()),
              leading:
                  const Icon(Icons.payments_outlined, color: Color(0xFF10B981)),
              onTap: () => Navigator.pop(context, 'CASH'),
            ),
            ListTile(
              title: Text('Online / UPI', style: GoogleFonts.inter()),
              leading: const Icon(Icons.qr_code_2, color: Color(0xFF4F46E5)),
              onTap: () => Navigator.pop(context, 'ONLINE'),
            ),
          ],
        ),
      ),
    );

    if (newMode != null &&
        newMode.toLowerCase() != token.paymentMode.toLowerCase()) {
      try {
        await RestaurantApi.instance.updateTokenPaymentMode(token.id, newMode);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment mode updated successfully!')));
        _loadTokens();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  Future<void> _deleteToken(ApiToken token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Bill',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete this bill (#${token.billNumber})? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await RestaurantApi.instance.deleteToken(token.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bill deleted successfully')));
          _loadTokens();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  void _editToken(ApiToken token) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TokenGenerationScreen(editToken: token),
      ),
    );
    if (result == true) _loadTokens();
  }
}
