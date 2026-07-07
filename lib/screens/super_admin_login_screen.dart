import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';
import 'super_admin_dashboard_screen.dart';

class SuperAdminLoginScreen extends StatefulWidget {
  const SuperAdminLoginScreen({super.key});

  @override
  State<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool _isDevMode = false;
  List<dynamic> _devSuperAdmins = [];
  bool _isLoadingDevUsers = false;

  Future<void> _fetchDevUsers() async {
    setState(() => _isLoadingDevUsers = true);
    try {
      final users = await RestaurantApi.instance.fetchDevUsers();
      setState(() {
        _devSuperAdmins = users.where((u) => u['is_superuser'] == true).toList();
      });
    } catch (e) {
      _showSnack('Failed to load dev super admins: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDevUsers = false);
    }
  }

  Future<void> _devSuperAdminLogin(String phone) async {
    setState(() => _isLoading = true);
    try {
      await RestaurantApi.instance.devLogin(phone);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SuperAdminDashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnack('Dev Super Admin Login failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    if (_idController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showSnack('Please enter both ID and Password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await RestaurantApi.instance.superAdminLogin(
        _idController.text.trim(),
        _passwordController.text.trim(),
      );

      if (response.containsKey('access')) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SuperAdminDashboardScreen()),
          (route) => false,
        );
      } else {
        _showSnack(response['error'] ?? 'Login failed');
      }
    } catch (e) {
      _showSnack('Failed to connect: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Dev Mode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.deepPurple)),
                      Switch(
                        value: _isDevMode,
                        activeThumbColor: Colors.deepPurple,
                        onChanged: (val) {
                          setState(() => _isDevMode = val);
                          if (val && _devSuperAdmins.isEmpty) {
                            _fetchDevUsers();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.admin_panel_settings_rounded, size: 56, color: Color(0xFF4F46E5)),
                const SizedBox(height: 16),
                Text(
                  'Super Admin',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to platform control center',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),
                
                if (_isDevMode)
                  _buildDevSuperAdminList(),
                
                // Login ID
                Text(
                  'LOGIN ID',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _idController,
                  decoration: InputDecoration(
                    hintText: 'Enter admin ID',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (!_isDevMode) ...[
                  // Password
                  Text(
                    'PASSWORD',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    if (_isDevMode) {
                      if (_idController.text.trim().isNotEmpty) {
                        _devSuperAdminLogin(_idController.text.trim());
                      } else {
                        _showSnack('Please enter Admin ID or select from the list');
                      }
                    } else {
                      _login();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Login',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevSuperAdminList() {
    if (_isLoadingDevUsers) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
      );
    }
    if (_devSuperAdmins.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('No active super admins found')),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _devSuperAdmins.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final u = _devSuperAdmins[index];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
            ),
            title: Text(u['name'] ?? 'Super Admin', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(u['phone'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            trailing: const Icon(Icons.login, size: 18, color: Color(0xFF94A3B8)),
            onTap: () => _devSuperAdminLogin(u['phone']),
          );
        },
      ),
    );
  }
}
