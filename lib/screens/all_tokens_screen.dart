import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


import '../services/restaurant_api.dart';
import 'print_preview_screen.dart';

class AllTokensScreen extends StatefulWidget {
  const AllTokensScreen({super.key});

  @override
  State<AllTokensScreen> createState() => _AllTokensScreenState();
}

class _AllTokensScreenState extends State<AllTokensScreen> {
  static const Color _panelBackground = Color(0xFFF8FAFC);
  static const Color _textPrimary = Color(0xFF0F172A);

  List<ApiToken> _tokens = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTokens();
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
          customerPhone: token.customerPhone,
          paymentMode: token.paymentMode,
          items: token.items.map((e) => ApiTokenItemDraft(
            id: e.id,
            name: e.name,
            code: e.code,
            rate: e.rate,
            quantity: e.quantity,
          )).toList(),
          subtotal: subtotal,
          tax: tax > 0 ? tax : 0.0,
          grandTotal: token.grandTotal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panelBackground,
      appBar: AppBar(
        title: Text('Token History', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _textPrimary, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textPrimary),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_tokens.isEmpty) {
      return Center(
        child: Text('No tokens found.', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B))),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTokens,
      color: const Color(0xFF4F46E5),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        itemCount: _tokens.length,
        itemBuilder: (context, index) {
          final token = _tokens[index];
          return _buildTokenCard(token);
        },
      ),
    );
  }

  Widget _buildTokenCard(ApiToken token) {
    Color statusColor;
    String statusText = token.status.toUpperCase();
    if (statusText == 'COMPLETED') {
      statusColor = const Color(0xFF10B981);
    } else if (statusText == 'CANCELLED') {
      statusColor = const Color(0xFFEF4444);
    } else {
      statusColor = const Color(0xFF3B82F6);
    }

    final isDelivery = token.orderType.toLowerCase() == 'delivery';
    final cName = token.customerName.trim();
    String displayTitle;
    if (isDelivery) {
      displayTitle = cName.isNotEmpty ? 'Delivery - $cName' : 'Delivery';
    } else {
      displayTitle = cName.isNotEmpty ? 'Walk-in - $cName' : 'Walk-in';
    }

    if (token.billNumber.isNotEmpty) {
      displayTitle += ' (#${token.billNumber})';
    }
    
    final tNum = token.tokenNumber.contains('#') ? token.tokenNumber : '#${token.tokenNumber}';

    return GestureDetector(
      onTap: () => _openPrintPreview(token),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('TOKEN', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  Text(tNum, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayTitle, 
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('\u20B9${token.grandTotal.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatTime(token.createdAt), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                      Expanded(
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => _changePaymentMode(token),
                              child: Container(
                                margin: const EdgeInsets.only(right: 4, bottom: 2, top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      token.paymentMode.isNotEmpty ? token.paymentMode.toUpperCase() : 'CASH',
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.edit, size: 10, color: Color(0xFF475569)),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 2, top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1), 
                                borderRadius: BorderRadius.circular(6)
                              ),
                              child: Text(statusText, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                            ),
                          ],
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
    );
  }

  Future<void> _changePaymentMode(ApiToken token) async {
    final newMode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Payment Mode', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Cash', style: GoogleFonts.inter()),
              leading: const Icon(Icons.payments_outlined, color: Color(0xFF10B981)),
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

    if (newMode != null && newMode.toLowerCase() != token.paymentMode.toLowerCase()) {
      try {
        await RestaurantApi.instance.updateTokenPaymentMode(token.id, newMode);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment mode updated successfully!')));
        _loadTokens();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }
}
