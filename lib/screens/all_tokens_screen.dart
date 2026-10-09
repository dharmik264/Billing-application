import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/restaurant_api.dart';
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
  String _paymentModeFilter = 'all'; // 'all', 'cash', 'online'
  DateTime? _selectedDate;
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
    return _tokens.where((t) {
      // Payment mode filter
      if (_paymentModeFilter == 'cash' && t.paymentMode.toLowerCase() != 'cash') {
        return false;
      }
      if (_paymentModeFilter == 'online' && t.paymentMode.toLowerCase() != 'online' && t.paymentMode.toLowerCase() != 'upi') {
        return false;
      }

      // Date filter
      if (_selectedDate != null) {
        try {
          final dt = DateTime.parse(t.createdAt).toLocal();
          if (dt.year != _selectedDate!.year || dt.month != _selectedDate!.month || dt.day != _selectedDate!.day) {
            return false;
          }
        } catch (_) {}
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return t.tokenNumber.toLowerCase().contains(q) ||
            t.billNumber.toLowerCase().contains(q) ||
            t.customerName.toLowerCase().contains(q) ||
            t.customerPhone.contains(q);
      }
      return true;
    }).toList();
  }

  int get _cashCount => _tokens.where((t) => t.paymentMode.toLowerCase() == 'cash').length;
  int get _onlineCount => _tokens.where((t) => t.paymentMode.toLowerCase() == 'online' || t.paymentMode.toLowerCase() == 'upi').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: CustomAppBar(
        title: 'Token & Bill History',
        icon: Icons.history_rounded,
        subtitle: '${_tokens.length} total bills',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF111111)),
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
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
        children: [
          // Search & Filter header section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
            ),
            child: Column(
              children: [
                // Search Bar
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.search, size: 18, color: Color(0xFF71717A)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF111111)),
                          decoration: InputDecoration(
                            hintText: 'Search by Token #, Bill #, Customer Name...',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFA1A1AA)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Color(0xFF71717A)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Horizontal filter pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill(
                        label: 'All Bills (${_tokens.length})',
                        isSelected: _paymentModeFilter == 'all' && _selectedDate == null,
                        onTap: () {
                          setState(() {
                            _paymentModeFilter = 'all';
                            _selectedDate = null;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildFilterPill(
                        label: 'Cash ($_cashCount)',
                        isSelected: _paymentModeFilter == 'cash',
                        onTap: () {
                          setState(() => _paymentModeFilter = _paymentModeFilter == 'cash' ? 'all' : 'cash');
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildFilterPill(
                        label: 'Online ($_onlineCount)',
                        isSelected: _paymentModeFilter == 'online',
                        onTap: () {
                          setState(() => _paymentModeFilter = _paymentModeFilter == 'online' ? 'all' : 'online');
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildFilterPill(
                        label: _selectedDate == null
                            ? 'Filter by Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        isSelected: _selectedDate != null,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          } else if (_selectedDate != null) {
                            setState(() => _selectedDate = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(child: _buildBody()),
        ],
      ),
    ),
  ),
),
);
  }

  Widget _buildFilterPill({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF111111) : const Color(0xFFE5E5E5)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF71717A),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF111111)),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF71717A)),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: const Color(0xFF71717A))),
          ],
        ),
      );
    }

    final list = _filteredTokens;

    if (list.isEmpty) {
      return Center(
        child: Text('No matching tokens found.', style: GoogleFonts.inter(color: const Color(0xFF71717A))),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTokens,
      color: const Color(0xFF111111),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      statusBg = const Color(0xFFF0FDF4);
      statusBorder = const Color(0xFFDCFCE7);
      statusText = const Color(0xFF166534);
    } else if (statusLabel == 'CANCELLED') {
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFEE2E2);
      statusText = const Color(0xFF991B1B);
    } else {
      statusBg = const Color(0xFFEFF6FF);
      statusBorder = const Color(0xFFDBEAFE);
      statusText = const Color(0xFF1E40AF);
    }

    final cName = token.customerName.trim();
    String displayCustomerName = cName.isNotEmpty ? cName : 'Token #${token.tokenNumber}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openPrintPreview(token),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Token badge + Customer name + Amount
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF111111), width: 1),
                    ),
                    child: Text(
                      'TOKEN ${token.tokenNumber}',
                      style: GoogleFonts.robotoMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      token.billNumber.isNotEmpty
                          ? '$displayCustomerName (#${token.billNumber})'
                          : displayCustomerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                  Text(
                    '\u20B9${token.grandTotal.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Middle row: Time + Payment mode pill + Status pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(token.createdAt),
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      color: const Color(0xFF71717A),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _changePaymentMode(token),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                token.paymentMode.isNotEmpty ? token.paymentMode.toUpperCase() : 'CASH',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF111111),
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.edit_outlined, size: 10, color: Color(0xFF71717A)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusBorder),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Bottom row: Action Buttons (Jama, Edit, Delete)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!token.isPaid && token.status.toLowerCase() != 'cancelled') ...[
                    GestureDetector(
                      onTap: () => _showTokenJamaDialog(token),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFDCFCE7)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined, size: 12, color: Color(0xFF166534)),
                            const SizedBox(width: 3),
                            Text(
                              'Jama (\u20B9 જમા)',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF166534)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  GestureDetector(
                    onTap: () => _editToken(token),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF71717A)),
                          const SizedBox(width: 3),
                          Text(
                            'Edit',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF111111)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _deleteToken(token),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFEE2E2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFFDC2626)),
                          const SizedBox(width: 3),
                          Text(
                            'Delete',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF991B1B)),
                          ),
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
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded,
                        color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bill #${token.billNumber} Jama',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: const Color(0xFF111111)),
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
                        color: const Color(0xFFF5F3F3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (token.customerName.isNotEmpty)
                            Text(token.customerName,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: const Color(0xFF111111))),
                          Text(
                              'Bill Total: \u20B9${token.grandTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF71717A))),
                          if (token.receivedAmount > 0)
                            Text(
                                'Already Paid: \u20B9${token.receivedAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF166534))),
                          if (token.balanceDue > 0)
                            Text(
                                'Remaining Due: \u20B9${token.balanceDue.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF991B1B))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Jama Amount (\u20B9 જમા રકમ)',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: const Color(0xFF111111))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        prefixText: '\u20B9 ',
                        hintText: 'Enter amount...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF111111), width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Payment Mode (ચૂકવણી મોડ)',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: const Color(0xFF111111))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Cash'),
                            selected: selectedMode == 'CASH',
                            selectedColor: const Color(0xFF111111),
                            labelStyle: TextStyle(
                              color: selectedMode == 'CASH' ? Colors.white : const Color(0xFF111111),
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() => selectedMode = 'CASH');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('UPI'),
                            selected: selectedMode == 'ONLINE',
                            selectedColor: const Color(0xFF111111),
                            labelStyle: TextStyle(
                              color: selectedMode == 'ONLINE' ? Colors.white : const Color(0xFF111111),
                              fontSize: 12,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() => selectedMode = 'ONLINE');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Card'),
                            selected: selectedMode == 'CARD',
                            selectedColor: const Color(0xFF111111),
                            labelStyle: TextStyle(
                              color: selectedMode == 'CARD' ? Colors.white : const Color(0xFF111111),
                              fontSize: 12,
                            ),
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
                      style: GoogleFonts.inter(color: const Color(0xFF71717A))),
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
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Submit Jama (\u20B9 જમા)',
                          style:
                              GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
            backgroundColor: const Color(0xFF166534),
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
                GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Cash', style: GoogleFonts.inter()),
              leading:
                  const Icon(Icons.payments_outlined, color: Color(0xFF111111)),
              onTap: () => Navigator.pop(context, 'CASH'),
            ),
            ListTile(
              title: Text('Online / UPI', style: GoogleFonts.inter()),
              leading: const Icon(Icons.qr_code_2, color: Color(0xFF111111)),
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
