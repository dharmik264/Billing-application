import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/restaurant_api.dart';
import '../utils/app_constants.dart';
import '../widgets/stat_card.dart';

class SuperAdminShopRequestsScreen extends StatefulWidget {
  const SuperAdminShopRequestsScreen({super.key});

  @override
  State<SuperAdminShopRequestsScreen> createState() => _SuperAdminShopRequestsScreenState();
}

class _SuperAdminShopRequestsScreenState extends State<SuperAdminShopRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  int _approvedCount = 0;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final users = await RestaurantApi.instance.fetchSuperAdminUsers();
      if (mounted) {
        setState(() {
          _requests = users;
          _approvedCount = users.where((u) => u['account_status'] == 'approved').length;
          _pendingCount = users.where((u) => u['account_status'] == 'pending' || u['account_status'] == 'trial').length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load requests: $e')),
        );
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('All Shop Requests', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18, color: const Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(child: StatCard(title: 'Pending Requests', value: _pendingCount.toString(), color: AppColors.amber500, compact: true)),
                          const SizedBox(width: 16),
                          Expanded(child: StatCard(title: 'Approved Shops', value: _approvedCount.toString(), color: AppColors.emerald500, compact: true)),
                        ],
                      ),
                    ),
                  ),
                  _requests.isEmpty
                      ? SliverFillRemaining(
                          child: Center(child: Text('No shop requests found.', style: GoogleFonts.inter(color: const Color(0xFF64748B)))),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildRequestCard(_requests[index], index).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.2),
                              childCount: _requests.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }



  Widget _buildRequestCard(Map<String, dynamic> req, int index) {
    final status = req['account_status'] ?? 'pending';
    final isApproved = status == 'approved';
    final isPending = status == 'pending' || status == 'trial';
    final name = req['shop_name'] ?? 'Unknown Shop';
    final location = req['phone'] ?? 'Unknown Phone';
    final userId = req['id'];
    final plan = req['approved_plan'] ?? 'Pro Plan';

    return GestureDetector(
      onTap: () => _showShopDetails(req),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isApproved ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isApproved ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.storefront,
                    color: isApproved ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$location • ${status.toString().toUpperCase()}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isApproved
                              ? const Color(0xFF16A34A)
                              : (isPending ? const Color(0xFFD97706) : const Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isApproved ? 'ACTIVE' : 'INACTIVE',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isApproved ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch.adaptive(
                            value: isApproved,
                            activeTrackColor: const Color(0xFF16A34A),
                            onChanged: (value) async {
                              try {
                                if (value) {
                                  await RestaurantApi.instance.approveShopRequest(userId.toString(), plan);
                                  _showSnack('$name activated!');
                                } else {
                                  await RestaurantApi.instance.declineShopRequest(userId.toString());
                                  _showSnack('$name deactivated!');
                                }
                                _fetchRequests();
                              } catch (e) {
                                _showSnack('Error updating status: $e');
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                      padding: const EdgeInsets.only(left: 4),
                      constraints: const BoxConstraints(),
                      onPressed: () => _confirmDeleteUser(req, index),
                    ),
                  ],
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _actionBtn('Approve', const Color(0xFF10B981), () async {
                    try {
                      await RestaurantApi.instance.approveShopRequest(userId.toString(), 'Pro Plan');
                      _fetchRequests();
                      _showSnack('$name approved!');
                    } catch (e) {
                      _showSnack('Failed to approve: $e');
                    }
                  }),
                  const SizedBox(width: 8),
                  _actionBtn('Decline', const Color(0xFFEF4444), () async {
                    try {
                      await RestaurantApi.instance.declineShopRequest(userId.toString());
                      _fetchRequests();
                      _showSnack('$name declined');
                    } catch (e) {
                      _showSnack('Failed to decline: $e');
                    }
                  }),
                ],
              ),
            ]
          ],
        ),
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

  void _confirmDeleteUser(Map<String, dynamic> req, int index) {
    final userId = req['id'];
    final name = req['shop_name'] ?? req['name'] ?? 'this profile';
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete Profile?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18)),
          content: Text('Are you sure you want to permanently delete $name? This will erase all their shop data and bills.', 
            style: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await RestaurantApi.instance.deleteSuperAdminUser(userId.toString());
                  setState(() {
                    _requests.removeAt(index);
                  });
                  _showSnack('Profile deleted successfully');
                } catch (e) {
                  _showSnack('Failed to delete: $e');
                }
              },
              child: Text('Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showShopDetails(Map<String, dynamic> req) {
    Map<String, dynamic>? shopSetup = req['shop_setup'];
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.storefront, color: Color(0xFFF59E0B), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['shop_name'] ?? req['name'], style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text(req['phone'] ?? 'No Phone', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                Text('SHOP SETUP DETAILS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 1.0)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Address', shopSetup?['address']),
                      _buildDetailRow('Phone', shopSetup?['phone']),
                      _buildDetailRow('Alt Phone', shopSetup?['alternate_phone']),
                      _buildDetailRow('Email', shopSetup?['email']),
                      _buildDetailRow('GSTIN', shopSetup?['gstin']),
                      _buildDetailRow('FSSAI', shopSetup?['fssai']),
                      _buildDetailRow('UPI ID', shopSetup?['upi_id']),
                      _buildDetailRow('Payments', shopSetup?['payment_modes_config']),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close Details', style: GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    final displayValue = (value == null || value.trim().isEmpty) ? 'Not Provided' : value;
    final isMissing = displayValue == 'Not Provided';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: GoogleFonts.inter(
                fontSize: 13, 
                fontWeight: isMissing ? FontWeight.w400 : FontWeight.w600,
                color: isMissing ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                fontStyle: isMissing ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
