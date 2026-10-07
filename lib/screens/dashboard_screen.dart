import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String _shopName = 'Dhara Food POS';

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

    if (!forceRefresh) {
      final cachedShop = RestaurantApi.instance.shopData;
      if (cachedShop != null) {
        _shopName = cachedShop.name.isNotEmpty ? cachedShop.name : 'Dhara Food POS';
        _smsCredits = cachedShop.smsCredits;
        _isLoading = false;
      }
    }

    if (_recentTokens.isEmpty && _isLoading) {
      setState(() => _isLoading = true);
    }

    try {
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
          _shopName = shop.name.isNotEmpty ? shop.name : 'Dhara Food POS';
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
            final formattedTime = '$year-$month-$day $hour:$minute';
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
      // Fallback
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: CustomAppBar(
        title: _shopName,
        icon: Icons.storefront_rounded,
        subtitle: _isOnline ? 'Online Sync' : 'Local Mode',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFBA1A1A), size: 20),
              tooltip: 'Logout',
              onPressed: () async {
                bool? confirm = await showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    content: Text('Are you sure you want to logout?', style: GoogleFonts.inter()),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBA1A1A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text('Logout', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
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
            constraints: const BoxConstraints(maxWidth: 800),
            child: RefreshIndicator(
              onRefresh: refreshData,
              color: const Color(0xFF111111),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Metric Summary Matrix (3x2 Ledger Grid)
                    _buildMetricMatrix(),
                    const SizedBox(height: 16),
                    // 2. Primary Action Button ("New Bill")
                    _buildNewBillButton(),
                    const SizedBox(height: 16),
                    // 3. Transaction Section (Ledger Table)
                    _buildTransactionLedger(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Metric Summary Matrix (3x2 Ledger Grid)
  Widget _buildMetricMatrix() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          // Row 1: Today Sales | Tokens | SMS
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Today Sales', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF5D5F5F))),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\u20B9${_totalSales.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF111111), letterSpacing: -0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E5E5)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Tokens', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF5D5F5F))),
                        const SizedBox(height: 4),
                        Text(
                          '$_tokenCount',
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF111111), letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E5E5)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('SMS', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF5D5F5F))),
                        const SizedBox(height: 4),
                        Text(
                          '$_smsCredits',
                          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF111111), letterSpacing: -0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),
          // Row 2: Cash Sales | Online Sales | Udhar Outstanding
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cash Sales', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF5D5F5F))),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\u20B9${_cashSales.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF111111), letterSpacing: -0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E5E5)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Online Sales', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF5D5F5F))),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\u20B9${_onlineSales.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF111111), letterSpacing: -0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E5E5)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Udhar Outstanding',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF5D5F5F)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '\u20B9${_udharSales.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF111111), letterSpacing: -0.3),
                          ),
                        ),
                      ],
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

  /// 2. Primary Action Button ("New Bill")
  Widget _buildNewBillButton() {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF111111),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TokenGenerationScreen()),
          );
          refreshData();
        },
        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
        label: Text(
          'New Bill',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
        ),
      ),
    );
  }

  /// 3. Transaction Section (Ledger Table)
  Widget _buildTransactionLedger() {
    final displayTokens = _recentTokens.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F3F3),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(7), topRight: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Transaction details',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF5D5F5F)),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF5D5F5F)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 65,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF5D5F5F)),
                  ),
                ),
              ],
            ),
          ),
          // Table Body Rows
          if (_isLoading && _recentTokens.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF111111))),
            )
          else if (displayTokens.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text('No transactions today', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF747878))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayTokens.length,
              separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),
              itemBuilder: (context, index) {
                final token = displayTokens[index];
                return _buildLedgerRow(token);
              },
            ),
          // Ledger Footer Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E5E5))),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(7), bottomRight: Radius.circular(7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_recentTokens.length} transactions today',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF5D5F5F)),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AllTokensScreen()),
                    );
                  },
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111111)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerRow(_LiveToken token) {
    final name = token.rawToken.customerName.isNotEmpty ? token.rawToken.customerName : 'Dhara Food';
    
    // Status text mapping
    String statusStr = 'Paid';
    final pm = token.paymentMode.toLowerCase();
    if (token.status.toUpperCase() == 'CANCELLED') {
      statusStr = 'Cancelled';
    } else if (pm == 'credit' || pm == 'udhar' || pm == 'due' || token.rawToken.balanceDue > 0) {
      if (token.rawToken.receivedAmount > 0) {
        statusStr = 'Partial';
      } else {
        statusStr = 'Pending';
      }
    } else {
      statusStr = 'Paid';
    }

    return InkWell(
      onTap: () => _showTokenOptions(token),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Left: Name & Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF111111)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${token.time} • ${token.orderId}',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF747878)),
                  ),
                ],
              ),
            ),
            // Middle: Amount
            SizedBox(
              width: 90,
              child: Text(
                '\u20B9${token.amount.toStringAsFixed(0)}',
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF111111)),
              ),
            ),
            const SizedBox(width: 8),
            // Right: Status Badge
            SizedBox(
              width: 65,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEDED),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusStr,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF111111)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTokenOptions(_LiveToken token) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5E5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          token.orderId,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF111111)),
                        ),
                        Text(
                          'Token ${token.tokenNumber} • \u20B9${token.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF747878)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF5D5F5F)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E5E5)),
              ListTile(
                leading: const Icon(Icons.print_outlined, color: Color(0xFF111111)),
                title: Text('Print / View Preview', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
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
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Color(0xFF111111)),
                title: Text('Edit Bill', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _editToken(token);
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment_outlined, color: Color(0xFF111111)),
                title: Text('Change Payment Mode', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _changePaymentMode(token);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFBA1A1A)),
                title: Text('Delete Bill', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFFBA1A1A))),
                onTap: () {
                  Navigator.pop(context);
                  _deleteToken(token);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changePaymentMode(_LiveToken token) async {
    final newMode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Payment Mode', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Cash', style: GoogleFonts.inter()),
              leading: const Icon(Icons.payments_outlined, color: Colors.green),
              onTap: () => Navigator.pop(context, 'CASH'),
            ),
            ListTile(
              title: Text('Online / UPI', style: GoogleFonts.inter()),
              leading: const Icon(Icons.qr_code_2, color: Colors.blue),
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
        title: Text('Delete Bill', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete this bill (${token.orderId})? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
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
