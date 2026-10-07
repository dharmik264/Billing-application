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
import '../utils/app_constants.dart';

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
  double _todayUdhar = 0.0;
  double _totalCustomerDue = 0.0;

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
          
          _todayUdhar = summary.creditTotal > 0 ? summary.creditTotal : calcUdhar;
          _totalCustomerDue = totalCustomerNetDue;
          _udharSales = _totalCustomerDue > 0 ? _totalCustomerDue : _todayUdhar;

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
      backgroundColor: StitchColors.background,
      appBar: CustomAppBar(
        title: _shopName,
        icon: Icons.storefront_rounded,
        subtitle: _isOnline ? 'Online Sync' : 'Local Mode',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: StitchColors.dangerText, size: 20),
              tooltip: 'Logout',
              onPressed: () async {
                bool? confirm = await showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text('Logout', style: StitchTypography.header()),
                    content: Text('Are you sure you want to logout?', style: StitchTypography.body()),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text('Cancel', style: StitchTypography.body(color: StitchColors.textMuted)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StitchColors.dangerText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        ),
                        child: Text('Logout', style: StitchTypography.body(color: Colors.white, weight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  await RestaurantApi.instance.clearTokens();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const PasswordLoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: RefreshIndicator(
              onRefresh: refreshData,
              color: StitchColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoading && _recentTokens.isEmpty)
                            _buildShimmerLoading()
                          else
                            _buildStatGrid(),
                          const SizedBox(height: 20),
                          // Section Header
                          Container(
                            decoration: const BoxDecoration(
                              color: StitchColors.surface,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(AppRadius.md),
                                topRight: Radius.circular(AppRadius.md),
                              ),
                              border: Border(
                                left: BorderSide(color: StitchColors.border, width: 1),
                                right: BorderSide(color: StitchColors.border, width: 1),
                                top: BorderSide(color: StitchColors.border, width: 1),
                                bottom: BorderSide(color: StitchColors.border, width: 1),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: StitchColors.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'RECENT TRANSACTIONS',
                                      style: StitchTypography.caption(color: StitchColors.textPrimary).copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const AllTokensScreen()),
                                    );
                                  },
                                  child: Text(
                                    'View All Transactions →',
                                    style: StitchTypography.caption(color: StitchColors.primary).copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _recentTokens.isEmpty && !_isLoading
                      ? SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: StitchColors.surface,
                              border: Border.all(color: StitchColors.border),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(AppRadius.md),
                                bottomRight: Radius.circular(AppRadius.md),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'No recent tokens found',
                                style: StitchTypography.body(color: StitchColors.textMuted),
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final token = _recentTokens[index];
                                return _buildTokenRow(token);
                              },
                              childCount: _recentTokens.length > 10 ? 10 : _recentTokens.length,
                            ),
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Flat shimmer placeholder
  Widget _buildShimmerLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemBuilder: (_, i) => Container(
            decoration: StitchDecorations.card(),
          ),
        ),
      ],
    );
  }

  /// Grid of stat metrics in Stitch Minimal Business style
  Widget _buildStatGrid() {
    final items = [
      _StatItem("Today's Sales", '\u20B9${_totalSales.toStringAsFixed(0)}', StitchColors.primary, Icons.payments_outlined),
      _StatItem('Total Tokens', _tokenCount.toString(), StitchColors.successText, Icons.confirmation_number_outlined),
      _StatItem('Cash Sales', '\u20B9${_cashSales.toStringAsFixed(0)}', StitchColors.infoText, Icons.point_of_sale_outlined),
      _StatItem('Online Sales', '\u20B9${_onlineSales.toStringAsFixed(0)}', StitchColors.warningText, Icons.qr_code_rounded),
      _StatItem('Net Customer Due', '\u20B9${_udharSales.toStringAsFixed(0)}', StitchColors.dangerText, Icons.account_balance_wallet_outlined),
      _StatItem(
        'SMS Credits',
        _smsCredits.toString(),
        _smsCredits > 10 ? StitchColors.textSecondary : StitchColors.dangerText,
        Icons.sms_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final cols = isWide ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: isWide ? 2.8 : 2.2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: StitchDecorations.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StitchTypography.caption(color: StitchColors.textMuted).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Icon(item.icon, size: 16, color: item.color),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.value,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: StitchColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Table-style token row matching Stitch Minimal Business
  Widget _buildTokenRow(_LiveToken token) {
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

    final pm = token.paymentMode.isEmpty ? 'CASH' : token.paymentMode.toUpperCase();

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PrintPreviewScreen(
            tokenNumber: token.tokenNumber,
            billNumber: token.rawToken.billNumber,
            customerName: token.rawToken.customerName.isNotEmpty ? token.rawToken.customerName : null,
            customerPhone: token.rawToken.customerPhone.isNotEmpty ? token.rawToken.customerPhone : null,
            customerAddress: token.rawToken.customerAddress.isNotEmpty ? token.rawToken.customerAddress : null,
            customerGstNumber: token.rawToken.customerGstNumber.isNotEmpty ? token.rawToken.customerGstNumber : null,
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
          color: StitchColors.surface,
          border: Border(
            left: BorderSide(color: StitchColors.border, width: 1),
            right: BorderSide(color: StitchColors.border, width: 1),
            bottom: BorderSide(color: StitchColors.border, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Token Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: StitchDecorations.badge(
                backgroundColor: StitchColors.surfaceSubtle,
                borderColor: StitchColors.border,
              ),
              child: Text(
                token.tokenNumber,
                style: StitchTypography.monospace(color: StitchColors.primary, size: 12),
              ),
            ),
            const SizedBox(width: 12),
            // Order ID & Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.orderId,
                    style: StitchTypography.header(size: 13),
                  ),
                  Text(
                    token.time,
                    style: StitchTypography.caption(),
                  ),
                ],
              ),
            ),
            // Payment Mode Pill
            GestureDetector(
              onTap: () => _changePaymentMode(token),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: StitchDecorations.badge(
                  backgroundColor: StitchColors.surfaceSubtle,
                  borderColor: StitchColors.border,
                ),
                child: Text(
                  pm,
                  style: StitchTypography.caption(color: StitchColors.textSecondary).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Amount
            Text(
              '\u20B9${token.amount.toStringAsFixed(0)}',
              style: StitchTypography.monospace(size: 14),
            ),
            const SizedBox(width: 12),
            // Status Badge
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
            const SizedBox(width: 8),
            // Actions
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16, color: StitchColors.textMuted),
              onPressed: () => _editToken(token),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: StitchColors.dangerText),
              onPressed: () => _deleteToken(token),
              visualDensity: VisualDensity.compact,
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
        title: Text('Change Payment Mode', style: StitchTypography.header()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Cash', style: StitchTypography.body()),
              leading: const Icon(Icons.payments_outlined, color: StitchColors.successText),
              onTap: () => Navigator.pop(context, 'CASH'),
            ),
            ListTile(
              title: Text('Online / UPI', style: StitchTypography.body()),
              leading: const Icon(Icons.qr_code_2, color: StitchColors.primary),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment mode updated successfully!')),
        );
        refreshData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _deleteToken(_LiveToken token) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Bill', style: StitchTypography.header()),
        content: Text(
          'Are you sure you want to delete this bill (${token.orderId})? This action cannot be undone.',
          style: StitchTypography.body(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: StitchTypography.body(color: StitchColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: StitchColors.dangerText,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            ),
            child: Text('Delete', style: StitchTypography.body(color: Colors.white, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await RestaurantApi.instance.deleteToken(token.rawToken.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bill deleted successfully')),
          );
          refreshData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  void _editToken(_LiveToken token) async {
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
  final IconData icon;
  const _StatItem(this.label, this.value, this.color, this.icon);
}

