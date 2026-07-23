import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/restaurant_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'password_login_screen.dart';
import 'super_admin_shop_requests_screen.dart';
import 'super_admin_user_roles_screen.dart';
import 'super_admin_plan_settings_screen.dart';
import 'super_admin_payment_settings_screen.dart';
import 'super_admin_payments_screen.dart';

// ── Models ──────────────────────────────────────────

class _ShopRequest {
  final int userId;
  final String name;
  final String location;
  final String plan;
  final String status; // pending or trial
  final IconData icon;
  final Color iconBg;

  const _ShopRequest({
    required this.userId,
    required this.name,
    required this.location,
    required this.plan,
    required this.status,
    required this.icon,
    required this.iconBg,
  });
}

// ── Dashboard Screen ──────────────────────────────────────────

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() => SuperAdminDashboardScreenState();
}

class SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  String _totalRevenue = '₹0';
  String _activeSubs = '0';

  late List<_ShopRequest> _shopRequests;
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _shopRequests = [];
    _fetchRequests();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await RestaurantApi.instance.fetchSuperAdminStats();
      if (mounted) {
        setState(() {
          _totalRevenue = '₹${stats['total_revenue']}';
          _activeSubs = stats['active_shops'].toString();
        });
      }
    } catch (e) {
      // Ignore stats fetch error for now
    }
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final requests = await RestaurantApi.instance.fetchShopRequests();
      setState(() {
        _shopRequests = requests.map((req) => _ShopRequest(
          userId: req['id'],
          name: req['shop_name'] ?? 'Unknown Shop',
          location: req['phone'] ?? 'Unknown Phone',
          plan: 'Pending Approval',
          status: req['account_status'],
          icon: Icons.storefront,
          iconBg: const Color(0xFFFFF7ED),
        )).toList();
        _isLoadingRequests = false;
      });
    } catch (e) {
      setState(() => _isLoadingRequests = false);
      _showSnack('Failed to load requests: $e');
    }
  }

  void refreshData() {
    _fetchRequests();
    _fetchStats();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await RestaurantApi.instance.clearTokens();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const PasswordLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshData();
        },
        color: const Color(0xFF4F46E5),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildStatCards().animate().fadeIn().slideY(begin: 0.1),
                    const SizedBox(height: 24),
                    _buildCoreManagement().animate().fadeIn().slideY(begin: 0.1, delay: 100.ms),
                    const SizedBox(height: 24),
                    _buildShopRequests().animate().fadeIn().slideY(begin: 0.1, delay: 200.ms),
                    const SizedBox(height: 24),
                    _buildSystemHealth().animate().fadeIn().slideY(begin: 0.1, delay: 300.ms),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. Header ──────────────────────────────────────────────

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Super Admin', style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 16)),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('SYSTEM ACTIVE', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 9, letterSpacing: 0.5)),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showSnack('Profile'),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Stat Cards ──────────────────────────────────────────

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(child: _bigStatCard('Total Revenue', _totalRevenue, Icons.trending_up_rounded, const Color(0xFF4F46E5), const Color(0xFF6366F1))),
        const SizedBox(width: 12),
        Expanded(child: _bigStatCard('Active Subs', _activeSubs, Icons.people_rounded, const Color(0xFF10B981), const Color(0xFF34D399))),
      ],
    );
  }

  Widget _bigStatCard(String title, String value, IconData icon, Color c1, Color c2) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: c1.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 14),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500, fontSize: 12)),
        ],
      ),
    );
  }


  // ── 4. Core Management ─────────────────────────────────────

  Widget _buildCoreManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CORE MANAGEMENT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _mgmtCard(Icons.bolt_rounded, 'User Roles', 'Manage permissions', const Color(0xFFFFF7ED), const Color(0xFFF59E0B), () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuperAdminUserRolesScreen()));
            }),
            _mgmtCard(Icons.pie_chart_rounded, 'Shop Approvals', 'View all requests', const Color(0xFFF0FDF4), const Color(0xFF10B981), () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuperAdminShopRequestsScreen()));
            }),
            _mgmtCard(Icons.history_rounded, 'Plan Settings', 'Edit pricing tiers', const Color(0xFFEFF6FF), const Color(0xFF3B82F6), () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuperAdminPlanSettingsScreen()));
            }),
            _mgmtCard(Icons.qr_code_2_rounded, 'Payment & QR', 'UPI & QR Code', const Color(0xFFF5F3FF), const Color(0xFF8B5CF6), () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuperAdminPaymentSettingsScreen()));
            }),
            _mgmtCard(Icons.receipt_long_rounded, 'User Payments', 'Verify UTR & Plan', const Color(0xFFECFDF5), const Color(0xFF059669), () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SuperAdminPaymentsScreen()));
            }),
          ],
        ),
      ],
    );
  }

  Widget _mgmtCard(IconData icon, String title, String subtitle, Color bgColor, Color iconColor, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap ?? () => _showSnack(title),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  // ── 5. Shop Requests ───────────────────────────────────────

  Widget _buildShopRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SHOP REQUESTS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.5)),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => const SuperAdminShopRequestsScreen(),
                )).then((_) => _fetchRequests());
              },
              child: Text('View All', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingRequests)
          const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else if (_shopRequests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No pending shop requests.', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13)),
            ),
          )
        else
          ...List.generate(
            _shopRequests.length > 3 ? 3 : _shopRequests.length,
            (i) => _shopRequestCard(_shopRequests[i], i),
          ),
      ],
    );
  }

  Widget _shopRequestCard(_ShopRequest req, int index) {
    final isPending = req.status == 'pending' || req.status == 'trial';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: req.iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(req.icon, color: const Color(0xFF64748B), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                const SizedBox(height: 3),
                Text('${req.location} • ${req.plan}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
          if (isPending)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _actionBtn('Approve', const Color(0xFF10B981), () async {
                  try {
                    await RestaurantApi.instance.approveShopRequest(req.userId.toString(), 'Pro Plan');
                    setState(() { _shopRequests.removeAt(index); });
                    _showSnack('${req.name} approved!');
                  } catch (e) {
                    _showSnack('Failed to approve: $e');
                  }
                }),
                const SizedBox(width: 6),
                _actionBtn('Decline', const Color(0xFFEF4444), () async {
                  try {
                    await RestaurantApi.instance.declineShopRequest(req.userId.toString());
                    setState(() { _shopRequests.removeAt(index); });
                    _showSnack('${req.name} declined');
                  } catch (e) {
                    _showSnack('Failed to decline: $e');
                  }
                }),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text('ACTIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  // ── 6. System Health ───────────────────────────────────────

  Widget _buildSystemHealth() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('System Health', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text('99.9% Uptime across all shards', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_rounded, size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text('MAINTENANCE MODE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 0.3)),
                      const SizedBox(width: 6),
                      Text('Next: Oct 30, 2025', style: GoogleFonts.inter(fontSize: 9, color: Colors.white54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showSnack('Schedule Maintenance'),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }



  // ── Helpers ────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
  }
}
