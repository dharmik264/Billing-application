import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/restaurant_api.dart';
import '../utils/app_constants.dart';
import '../widgets/stat_card.dart';
import 'printer_setup_screen.dart';
import 'print_preview_screen.dart';
import 'all_tokens_screen.dart';

class _LiveToken {
  final ApiToken rawToken;
  final String orderId;
  final String tokenNumber;
  final String time;
  final double amount;
  final String status;
  final String paymentMode;

  _LiveToken({
    required this.rawToken,
    required this.orderId,
    required this.tokenNumber,
    required this.time,
    required this.amount,
    required this.status,
    required this.paymentMode,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String _shopName = 'My Shop';
  Uint8List? _shopLogoBytes;

  int _tokenCount = 0;
  double _totalSales = 0.0;

  double _cashSales = 0.0;
  double _onlineSales = 0.0;

  List<_LiveToken> _recentTokens = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData(forceRefresh: true);
  }

  Future<void> refreshData() async {
    await _loadDashboardData(forceRefresh: true);
  }

  Future<void> _loadDashboardData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final shop = await RestaurantApi.instance.fetchShop(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _shopName = shop.name.isNotEmpty ? shop.name : 'My Shop';
          if (shop.logoUrl != null && shop.logoUrl!.isNotEmpty) {
            final uri = Uri.tryParse(shop.logoUrl!);
            if (uri != null && uri.scheme == 'data') {
              _shopLogoBytes = base64Decode(shop.logoUrl!.split(',').last);
            }
          }
        });
      }

      final summary = await RestaurantApi.instance.fetchAllTimeSummary(useCache: !forceRefresh);
      if (mounted) {
        setState(() {
          _tokenCount = summary.totalTokens;
          _totalSales = summary.totalSales;
          _cashSales = summary.cashTotal;
          _onlineSales = summary.onlineTotal;
        });
      }

      final tokens = await RestaurantApi.instance.fetchTokens();
      if (mounted) {
        setState(() {
          _recentTokens = tokens.map((t) {
            final date = DateTime.parse(t.createdAt).toLocal();
            return _LiveToken(
              rawToken: t,
              orderId: '#${t.billNumber}',
              tokenNumber: t.tokenNumber,
              time: '${date.hour > 12 ? date.hour - 12 : date.hour == 0 ? 12 : date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}',
              amount: t.grandTotal,
              status: t.status,
              paymentMode: t.paymentMode,
            );
          }).toList();
        });
      }
    } catch (e) {
      // Ignore errors for now
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: refreshData,
            color: const Color(0xFF4F46E5),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 140.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: const Color(0xFFEEF2FF),
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    title: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _shopLogoBytes != null
                              ? Image.memory(_shopLogoBytes!, fit: BoxFit.cover)
                              : const Icon(Icons.storefront_rounded, color: Color(0xFF4F46E5), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _shopName,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'System Online',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrinterSetupScreen())),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Icon(Icons.print_rounded, color: Color(0xFF4F46E5), size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _isLoading && _recentTokens.isEmpty
                      ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            _buildStatCards().animate().fadeIn().slideY(begin: 0.1, delay: 100.ms),
                            const SizedBox(height: 32),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Recent Tokens',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const AllTokensScreen()),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Text(
                                        'View All',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: _recentTokens.isEmpty && !_isLoading
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Text(
                                'No recent tokens found',
                                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return _buildTokenCard(_recentTokens[index])
                                  .animate()
                                  .fadeIn()
                                  .slideX(begin: 0.05, delay: (index * 50).ms);
                            },
                            childCount: _recentTokens.length > 3 ? 3 : _recentTokens.length,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          StatCard(title: "Today's Sales", value: '\u20B9${_totalSales.toStringAsFixed(0)}', icon: Icons.trending_up_rounded, color: AppColors.indigo600),
          const SizedBox(width: 10),
          StatCard(title: 'Tokens', value: _tokenCount.toString(), icon: Icons.receipt_long_rounded, color: AppColors.emerald500),
          const SizedBox(width: 10),
          StatCard(title: 'Online Sales', value: '\u20B9${_onlineSales.toStringAsFixed(0)}', icon: Icons.language_rounded, color: AppColors.amber500),
          const SizedBox(width: 10),
          StatCard(title: 'Cash Sales', value: '\u20B9${_cashSales.toStringAsFixed(0)}', icon: Icons.payments_rounded, color: const Color(0xFFEC4899)),
        ],
      ),
    );
  }

  Widget _buildTokenCard(_LiveToken token) {
    Color statusColor;
    String statusText = token.status.toUpperCase();
    if (statusText == 'COMPLETED') {
      statusColor = const Color(0xFF10B981);
    } else if (statusText == 'CANCELLED') {
      statusColor = const Color(0xFFEF4444);
    } else {
      statusColor = const Color(0xFF3B82F6);
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PrintPreviewScreen(
            tokenNumber: token.tokenNumber,
            billNumber: token.rawToken.billNumber,
            customerPhone: token.rawToken.customerPhone,
            paymentMode: token.paymentMode,
            items: token.rawToken.items.map((i) => ApiTokenItemDraft(
              name: i.name,
              code: i.code,
              quantity: i.quantity,
              rate: i.rate,
            )).toList(),
            subtotal: token.amount,
            tax: 0.0,
            grandTotal: token.amount,
          ),
        ));
      },
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
                  Text(
                    'TOKEN',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                  ),
                  Text(
                    token.tokenNumber,
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5)),
                  ),
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
                      Text(
                        token.orderId,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                      Text(
                        '\u20B9${token.amount.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        token.time,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
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
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusText,
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                              ),
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

  Future<void> _changePaymentMode(_LiveToken token) async {
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
        await RestaurantApi.instance.updateTokenPaymentMode(token.rawToken.id, newMode);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment mode updated successfully!')));
        refreshData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }
}
