import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/restaurant_api.dart';
import 'print_preview_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays every token from the database, newest-first.
class AllTokensScreen extends StatefulWidget {
  const AllTokensScreen({super.key});

  @override
  State<AllTokensScreen> createState() => _AllTokensScreenState();
}

class _AllTokensScreenState extends State<AllTokensScreen> {
  static const Color _panelBackground = Color(0xFFF5F6FA);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _softBorder = Color(0xFFEEEEEE);
  static const double _panelWidth = 360;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(_panelWidth, constraints.maxWidth);

                return Center(
                  child: Container(
                    width: width,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _buildPanel(),
                  ),
                );
              },
            ),
            if (_loading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_primary),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _panelBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _softBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.arrow_back, size: 19, color: Color(0xFF555555)),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Token History',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: _textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadTokens();
            },
            icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF888888)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: Color(0xFFBBBBBB)),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ],
        ),
      );
    }

    if (_tokens.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Text(
            'No tokens found.',
            style: TextStyle(fontSize: 13, color: _textSecondary),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: [
              // Summary badge
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_tokens.length} token${_tokens.length == 1 ? '' : 's'} total',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _primary,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _softBorder, width: 0.5),
                  ),
                  child: ListView.separated(
                    itemCount: _tokens.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
                    itemBuilder: (context, i) => _tokenRow(_tokens[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tokenRow(ApiToken token) {
    final isReady = token.status.toUpperCase() == 'READY' ||
        token.status.toUpperCase() == 'COMPLETED';
    final isCancelled = token.status.toUpperCase() == 'CANCELLED';

    final badgeBg = isCancelled
        ? const Color(0xFFFEE2E2)
        : isReady
            ? const Color(0xFFD1FAE5)
            : const Color(0xFFFFF3CD);
    final badgeFg = isCancelled
        ? const Color(0xFF991B1B)
        : isReady
            ? const Color(0xFF065F46)
            : const Color(0xFF92400E);

    final statusBg = badgeBg;
    final statusFg = badgeFg;

    final mode = token.paymentMode;
    final modeLabel = mode.isEmpty ? 'N/A' : _titleCase(mode);
    final timeStr = _formatTime(token.createdAt);

    final isDelivery = token.orderType.toLowerCase() == 'delivery';
    final cName = token.customerName.trim();
    String displayTitle;
    if (isDelivery) {
      displayTitle = cName.isNotEmpty ? 'Delivery - $cName' : 'Delivery';
    } else {
      displayTitle = cName.isNotEmpty ? 'Walk-in - $cName' : 'Walk-in';
    }

    if (token.billNumber.isNotEmpty) {
      displayTitle += ' (Bill: ${token.billNumber})';
    }

    return InkWell(
      onTap: () => _openPrintPreview(token),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          token.tokenNumber.contains('#') ? token.tokenNumber : '#${token.tokenNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: badgeFg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _titleCase(token.status).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: _textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          timeStr,
                          style: const TextStyle(fontSize: 12, color: _textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payment_outlined, size: 14, color: _textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          modeLabel,
                          style: const TextStyle(fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '₹${token.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: _textSecondary),
                        padding: EdgeInsets.zero,
                        onSelected: (val) {
                          if (val == 'view') {
                            _openPrintPreview(token);
                          } else if (val == 'whatsapp') {
                            _shareWhatsApp(token);
                          } else {
                            _showSnackBar('$val clicked');
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'view',
                              child: Text('View & Print', style: TextStyle(fontSize: 13))),
                          const PopupMenuItem(
                              value: 'whatsapp',
                              child: Text('Share on WhatsApp', style: TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPrintPreview(ApiToken token) {
    final subtotal = token.items.fold(0.0, (sum, item) => sum + item.subtotal);
    final tax = token.grandTotal - subtotal;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          tokenNumber: token.tokenNumber,
          billNumber: token.billNumber,
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

  Future<void> _shareWhatsApp(ApiToken token) async {
    final text =
        'Hello ${token.customerName},\nHere is your Bill #${token.tokenNumber} for Rs. ${token.grandTotal}.\nThank you for visiting!';
    final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showSnackBar('WhatsApp is not installed');
      }
    } catch (e) {
      _showSnackBar('Could not launch WhatsApp');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();

      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;

      final hour = dt.hour == 0
          ? 12
          : dt.hour > 12
              ? dt.hour - 12
              : dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final suffix = dt.hour >= 12 ? 'PM' : 'AM';

      return '$day/$month/$year, $hour:$minute $suffix';
    } catch (_) {
      return raw;
    }
  }
}
