import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';

class SuperAdminUserRolesScreen extends StatefulWidget {
  const SuperAdminUserRolesScreen({super.key});

  @override
  State<SuperAdminUserRolesScreen> createState() => _SuperAdminUserRolesScreenState();
}

class _SuperAdminUserRolesScreenState extends State<SuperAdminUserRolesScreen> {
  List<Map<String, dynamic>> _approvedUsers = [];
  bool _isLoading = true;

  final Map<String, String> _availablePermissions = {
    'billing': 'Billing & Invoicing',
    'inventory': 'Inventory Management',
    'reports': 'Reporting & Analytics',
    'tax': 'Tax Settings',
    'staff': 'Staff Management',
  };

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await RestaurantApi.instance.fetchSuperAdminUsers();
      if (mounted) {
        setState(() {
          _approvedUsers = users.where((u) => u['account_status'] == 'approved').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e')),
        );
      }
    }
  }

  void _showPermissionsDialog(Map<String, dynamic> user) {
    Map<String, dynamic> userPerms = user['permissions'] ?? {};
    Map<String, dynamic>? shopSetup = user['shop_setup'];
    
    // Initialize current toggles based on user's permissions
    Map<String, bool> currentToggles = {};
    for (var key in _availablePermissions.keys) {
      currentToggles[key] = userPerms[key] ?? true; 
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, controller) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 20, right: 20, top: 20,
                  ),
                  child: ListView(
                    controller: controller,
                    children: [
                      Text('User Details & Roles', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(user['shop_name'] ?? user['name'], style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                      const SizedBox(height: 20),
                      
                      // Shop Details Section
                      Text('SHOP SETUP DETAILS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                            _buildDetailRow('Payment Modes', shopSetup?['payment_modes_config']),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Permissions Section
                      Text('MANAGE PERMISSIONS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8), letterSpacing: 0.5)),
                      const SizedBox(height: 12),
                      ..._availablePermissions.entries.map((e) {
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                          value: currentToggles[e.key] ?? false,
                          activeTrackColor: const Color(0xFF4F46E5),
                          onChanged: (val) {
                            setModalState(() {
                              currentToggles[e.key] = val;
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _updatePermissions(user['id'].toString(), currentToggles);
                          },
                          child: Text('Save Permissions', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Delete Profile Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmDelete(user);
                          },
                          child: Text('Delete Profile', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            );
          },
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

  void _confirmDelete(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete Profile?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Text('Are you sure you want to delete ${user['shop_name'] ?? user['name']}? This action is permanent and will remove all their shop data and bills.', style: GoogleFonts.inter(fontSize: 14)),
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
                await _deleteUser(user['id'].toString());
              },
              child: Text('Delete', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await RestaurantApi.instance.deleteSuperAdminUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile deleted successfully')),
      );
      _fetchUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  Future<void> _updatePermissions(String userId, Map<String, bool> permissions) async {
    try {
      await RestaurantApi.instance.updateUserPermissions(userId, permissions);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions updated successfully')),
      );
      _fetchUsers(); // Refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('User Roles', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18, color: const Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _approvedUsers.isEmpty
              ? Center(child: Text('No approved users found.', style: GoogleFonts.inter(color: const Color(0xFF64748B))))
              : RefreshIndicator(
                  onRefresh: _fetchUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _approvedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _approvedUsers[index];
                      final name = user['shop_name'] ?? 'Unknown Shop';
                      final phone = user['phone'] ?? 'Unknown Phone';

                      return GestureDetector(
                        onTap: () => _showPermissionsDialog(user),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.manage_accounts, color: Color(0xFF4F46E5), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                                    const SizedBox(height: 4),
                                    Text(phone, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
