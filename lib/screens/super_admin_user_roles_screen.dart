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
    
    // Initialize current toggles based on user's permissions
    Map<String, bool> currentToggles = {};
    for (var key in _availablePermissions.keys) {
      currentToggles[key] = userPerms[key] ?? true; // default true if not set, or you can default to false
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20, right: 20, top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manage Permissions', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(user['shop_name'] ?? user['name'], style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B))),
                  const SizedBox(height: 20),
                  ..._availablePermissions.entries.map((e) {
                    return SwitchListTile(
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
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
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
