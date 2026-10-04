import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/restaurant_api.dart';

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'password_login_screen.dart';
import 'print_preview_screen.dart';
import 'all_tokens_screen.dart';
import 'token_generation_screen.dart';
import '../widgets/custom_page_header.dart';
import '../services/sync_service.dart';
import '../utils/bill_event_notifier.dart';

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

  int _tokenCount = 0;
  int _smsCredits = 0;
  double _totalSales = 0.0;

  double _cashSales = 0.0;
  double _onlineSales = 0.0;
  double _udharSales = 0.0;

  List<_LiveToken> _recentTokens = [];

  bool _isOnline = SyncService.instance.isOnline;
  StreamSubscription<bool>? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadDashboardData(forceRefresh: false);
    _syncSub = SyncService.instance.onlineStatusStream.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
    BillEventNotifier.billRefreshNotifier.addListener(_onBillChanged);
  }

  void _onBillChanged() {
    if (mounted) {
      _loadDashboardData(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    BillEventNotifier.billRefreshNotifier.removeListener(_onBillChanged);
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> refreshData() async {
    await _loadDashboardData(forceRefresh: true);
  }

  Future<void> _loadDashboardData({bool forceRefresh = false}) async {
    if (!mounted) return;

    // Load cached data instantly so UI renders without delay
    if (!forceRefresh) {
      final cachedShop = RestaurantApi.instance.shopData;
      if (cachedShop != null) {
        _shopName = cachedShop.name.isNotEmpty ? cachedShop.name : 'My Shop';
        _smsCredits = cachedShop.smsCredits;
        _isLoading = false;
      }
    }

    if (_recentTokens.isEmpty && _isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      // Execute network requests in parallel for maximum speed
      final results = await Future.wait([
        RestaurantApi.instance.fetchShop(forceRefresh: forceRefresh),
        RestaurantApi.instance.fetchAllTimeSummary(useCache: !forceRefresh),
        RestaurantApi.instance.fetchTokens(),
        RestaurantApi.instance.fetchCustomers(),
      ]);

      final shop = results[0] as ApiShopData;
      final summary = results[1] as ApiSummaryReport;
      final tokens = results[2] as List<ApiToken>;
      final customers = results[3] as List<ApiCustomer>;

      if (mounted) {
        setState(() {
          _shopName = shop.name.isNotEmpty ? shop.name : 'My Shop';
          _smsCredits = shop.smsCredits;

          final now = DateTime.now();
          final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
          final todayTokens = tokens.where((t) {
            if (t.status.toLowerCase() == 'cancelled') return false;
            return t.createdAt.startsWith(todayStr);
          }).toList();

          double calcTotal = 0.0;
          double calcCash = 0.0;
          double calcOnline = 0.0;
          double calcUdhar = 0.0;
          for (var t in todayTokens) {
            calcTotal += t.grandTotal;
            final pm = t.paymentMode.toLowerCase();
            final dueAmount = t.balanceDue > 0
                ? t.balanceDue
                : (!t.isPaid ? (t.grandTotal - t.receivedAmount) : 0.0);

            if (dueAmount > 0 || pm == 'credit' || pm == 'udhar' || pm == 'due') {
              final netDue = dueAmount > 0 ? dueAmount : t.grandTotal;
              calcUdhar += netDue;
              final paidPortion = t.grandTotal - netDue;
              if (paidPortion > 0) {
                if (pm == 'online' || pm == 'upi' || pm == 'online / upi') {
                  calcOnline += paidPortion;
                } else {
                  calcCash += paidPortion;
                }
              }
            } else if (pm == 'online' || pm == 'upi' || pm == 'online / upi') {
              calcOnline += t.grandTotal;
            } else {
              calcCash += t.grandTotal;
            }
          }

          double totalCustomerNetDue = 0.0;
          for (var c in customers) {
            if (c.netDue > 0) {
              totalCustomerNetDue += c.netDue;
            }
          }

          _tokenCount = summary.totalTokens > 0
              ? summary.totalTokens
              : todayTokens.length;
          _totalSales = summary.totalSales > 0 ? summary.totalSales : calcTotal;
          _cashSales = summary.cashTotal > 0 ? summary.cashTotal : calcCash;
          _onlineSales = summary.onlineTotal > 0 ? summary.onlineTotal : calcOnline;
          
          final effectiveCredit = summary.creditTotal > 0 ? summary.creditTotal : calcUdhar;
          _udharSales = totalCustomerNetDue > 0 ? totalCustomerNetDue : effectiveCredit;

          _recentTokens = tokens.map((t) {
            final date = DateTime.parse(t.createdAt).toLocal();
            final day = date.day.toString().padLeft(2, '0');
            final month = date.month.toString().padLeft(2, '0');
            final year = date.year;
            final hour = date.hour > 12
                ? date.hour - 12
                : (date.hour == 0 ? 12 : date.hour);
            final minute = date.minute.toString().padLeft(2, '0');
            final period = date.hour >= 12 ? 'PM' : 'AM';
            final formattedTime = '$day/$month/$year, $hour:$minute $period';
            return _LiveToken(
              rawToken: t,
              orderId: '#${t.billNumber}',
              tokenNumber: t.tokenNumber,
              time: formattedTime,
              amount: t.grandTotal,
              status: t.status,
              paymentMode: t.paymentMode,
            );
          }).toList();
        });
      }
    } catch (e) {
      // Fallback gracefully on network delay/error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: _shopName,
        icon: Icons.storefront_rounded,
        subtitle: _isOnline ? 'Online' : 'Local',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () async {
                bool? confirm = await showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                          title: Text('Logout',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold)),
                          content:
                              const Text('Are you sure you want to logout?'),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(c, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero)),
                              child: const Text('Logout',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ));
                if (confirm == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  await RestaurantApi.instance.clearTokens();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const PasswordLoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFEF4444), size: 18),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshData,
        color: const Color(0xFF4F46E5),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _isLoading && _recentTokens.isEmpty
                  ? _buildShimmerLoading()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatGrid()
                            .animate()
                            .fadeIn(duration: 300.ms),
                        // Section header
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: Color(0xFFE2E8F0), width: 1),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'RECENT TOKENS',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const AllTokensScreen()),
                                  );
                                },
                                child: Text(
                                  'View All →',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF4F46E5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            _recentTokens.isEmpty && !_isLoading
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          'No recent tokens found',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final token = _recentTokens[index];
                        return _buildTokenRow(token)
                            .animate()
                            .fadeIn(delay: (index * 30).ms);
                      },
                      childCount: _recentTokens.length > 10
                          ? 10
                          : _recentTokens.length,
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  /// Flat shimmer placeholder
  Widget _buildShimmerLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shimmer grid: 2 columns x 3 rows = 6 cells
        Padding(
          padding: const EdgeInsets.all(0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
            ),
            itemBuilder: (_, i) => Container(
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 0.5),
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(
                  delay: (i * 80).ms,
                  duration: 1000.ms,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
        // Shimmer rows
        Column(
          children: List.generate(4, (i) => Container(
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(
                delay: (i * 100 + 200).ms,
                duration: 1000.ms,
                color: Colors.white.withValues(alpha: 0.7),
              )),
        ),
      ],
    );
  }

  /// 2-column fixed grid of stat metrics
  Widget _buildStatGrid() {
    final items = [
      _StatItem("Today's Sales", '\u20B9${_totalSales.toStringAsFixed(0)}',
          const Color(0xFF4F46E5)),
      _StatItem('Tokens', _tokenCount.toString(), const Color(0xFF059669)),
      _StatItem('Cash Sales', '\u20B9${_cashSales.toStringAsFixed(0)}',
          const Color(0xFF0284C7)),
      _StatItem('Online Sales', '\u20B9${_onlineSales.toStringAsFixed(0)}',
          const Color(0xFFD97706)),
      _StatItem('Udhar', '\u20B9${_udharSales.toStringAsFixed(0)}',
          const Color(0xFFDC2626)),
      _StatItem(
          'SMS Credits',
          _smsCredits.toString(),
          _smsCredits > 10
              ? const Color(0xFF64748B)
              : const Color(0xFFEF4444)),
    ];

    return Table(
      border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1),
      children: [
        for (int r = 0; r < 3; r++)
          TableRow(
            children: [
              _buildStatCell(items[r * 2]),
              _buildStatCell(items[r * 2 + 1]),
            ],
          ),
      ],
    );
  }

  Widget _buildStatCell(_StatItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.value,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: item.color,
            ),
          ),
        ],
      ),
    );
  }

  /// Flat table-style token row with thin bottom divider
  Widget _buildTokenRow(_LiveToken token) {
    Color statusColor;
    String statusText = token.status.toUpperCase();
    if (statusText == 'COMPLETED') {
      statusColor = const Color(0xFF059669);
    } else if (statusText == 'CANCELLED') {
      statusColor = const Color(0xFFDC2626);
    } else {
      statusColor = const Color(0xFF2563EB);
    }

    final pm = token.paymentMode.isEmpty ? 'CASH' : token.paymentMode.toUpperCase();

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PrintPreviewScreen(
            tokenNumber: token.tokenNumber,
            billNumber: token.rawToken.billNumber,
            customerName: token.rawToken.customerName.isNotEmpty
                ? token.rawToken.customerName
                : null,
            customerPhone: token.rawToken.customerPhone.isNotEmpty
                ? token.rawToken.customerPhone
                : null,
            customerAddress: token.rawToken.customerAddress.isNotEmpty
                ? token.rawToken.customerAddress
                : null,
            customerGstNumber: token.rawToken.customerGstNumber.isNotEmpty
                ? token.rawToken.customerGstNumber
                : null,
            paymentMode: token.paymentMode,
            items: token.rawToken.items
                .map((i) => ApiTokenItemDraft(
                      name: i.name,
                      code: i.code,
                      quantity: i.quantity,
                      rate: i.rate,
                    ))
                .toList(),
            subtotal: token.amount,
            tax: 0.0,
            grandTotal: token.amount,
          ),
        ));
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Token number badge — flat
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                token.tokenNumber,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4F46E5),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Bill # and time stacked
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.orderId,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    token.time,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            // Payment mode — tap to change
            GestureDetector(
              onTap: () => _changePaymentMode(token),
              child: Text(
                pm,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Amount
            Text(
              '\u20B9${token.amount.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            // Edit icon
            GestureDetector(
              onTap: () => _editToken(token),
              child: const Icon(Icons.edit_outlined,
                  size: 14, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 8),
            // Delete icon
            GestureDetector(
              onTap: () => _deleteToken(token),
              child: const Icon(Icons.delete_outline,
                  size: 14, color: Color(0xFFEF4444)),
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
        await RestaurantApi.instance
            .updateTokenPaymentMode(token.rawToken.id, newMode);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment mode updated successfully!')));
        refreshData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  Future<void> _deleteToken(_LiveToken token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Bill',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
            'Are you sure you want to delete this bill (${token.orderId})? This action cannot be undone.'),
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
        await RestaurantApi.instance.deleteToken(token.rawToken.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bill deleted successfully')));
          refreshData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  void _editToken(_LiveToken token) async {
    // Navigate to TokenGenerationScreen passing the editToken.
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TokenGenerationScreen(editToken: token.rawToken),
      ),
    );
    if (result == true) refreshData();
  }
}

class _StatItem {
  final String label;
  final String value;
  final Color color;
  const _StatItem(this.label, this.value, this.color);
}
