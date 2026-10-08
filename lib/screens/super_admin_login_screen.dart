import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/restaurant_api.dart';
import 'super_admin_main_screen.dart';

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
  bool _keepSessionActive = true;

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
      String errMsg = e.toString();
      if (errMsg.contains('SocketException') || errMsg.contains('Failed host lookup') || errMsg.contains('TimeoutException')) {
        errMsg = 'Unable to connect to server. Please try again.';
      } else {
        errMsg = 'Failed to load dev super admins. Error: $errMsg';
      }
      _showSnack(errMsg);
    } finally {
      if (mounted) setState(() => _isLoadingDevUsers = false);
    }
  }

  Future<void> _devSuperAdminLogin(String phone) async {
    setState(() => _isLoading = true);
    try {
      await RestaurantApi.instance.devLogin(phone);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('loginPhone', phone);
      await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SuperAdminMainScreen()),
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('loginPhone', _idController.text.trim());
        await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SuperAdminMainScreen()),
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
      backgroundColor: const Color(0xFFF5F3F3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF9F8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    // Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBF9F8),
                        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1B1C1C)),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Expanded(
                            child: Text(
                              'Dhara Food POS',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1B1C1C),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Dev Mode',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF5D5F5F),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 20,
                                width: 36,
                                child: Switch(
                                  value: _isDevMode,
                                  activeTrackColor: const Color(0xFF1B1C1C),
                                  onChanged: (val) {
                                    setState(() => _isDevMode = val);
                                    if (val) {
                                      RestaurantApi.instance.setCustomBaseUrl('http://127.0.0.1:8000/api');
                                      if (_devSuperAdmins.isEmpty) {
                                        _fetchDevUsers();
                                      }
                                    } else {
                                      RestaurantApi.instance.setCustomBaseUrl(null);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Main Card Container
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                children: [
                                  // Security Shield Badge Icon
                                  Stack(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFBF9F8),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFFE5E7EB)),
                                        ),
                                        child: const Icon(
                                          Icons.verified_user_outlined,
                                          size: 28,
                                          color: Color(0xFF1B1C1C),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1B1C1C),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          child: const Icon(Icons.person, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Super Admin',
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1B1C1C),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Sign in to platform control center',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: const Color(0xFF5D5F5F),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  if (_isDevMode) _buildDevSuperAdminList(),

                                  // Field 1: LOGIN ID
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'LOGIN ID',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF5D5F5F),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFE5E7EB)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 12),
                                              child: Icon(Icons.person_outline, size: 20, color: Color(0xFF5D5F5F)),
                                            ),
                                            Expanded(
                                              child: TextField(
                                                controller: _idController,
                                                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1B1C1C)),
                                                decoration: InputDecoration(
                                                  hintText: 'Enter admin ID',
                                                  hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5D5F5F)),
                                                  border: InputBorder.none,
                                                  contentPadding: const EdgeInsets.only(right: 12),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Field 2: PASSWORD
                                  if (!_isDevMode) ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'PASSWORD',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF5D5F5F),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                _showSnack('Contact platform administrator for key reset.');
                                              },
                                              child: Text(
                                                'Reset Key',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF5D5F5F),
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFE5E7EB)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 12),
                                                child: Icon(Icons.lock_outline, size: 20, color: Color(0xFF5D5F5F)),
                                              ),
                                              Expanded(
                                                child: TextField(
                                                  controller: _passwordController,
                                                  obscureText: _obscurePassword,
                                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1B1C1C)),
                                                  decoration: InputDecoration(
                                                    hintText: 'Enter password',
                                                    hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5D5F5F)),
                                                    border: InputBorder.none,
                                                    contentPadding: EdgeInsets.zero,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                                  size: 20,
                                                  color: const Color(0xFF5D5F5F),
                                                ),
                                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Session preservation check
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Checkbox(
                                            value: _keepSessionActive,
                                            activeColor: const Color(0xFF1B1C1C),
                                            onChanged: (val) => setState(() => _keepSessionActive = val ?? true),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Keep active ledger session (12h)',
                                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF5D5F5F)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Primary Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
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
                                        backgroundColor: const Color(0xFF1B1C1C),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text('Login', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                                                const SizedBox(width: 6),
                                                const Icon(Icons.arrow_forward, size: 18),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Audit notice
                                  Container(
                                    padding: const EdgeInsets.only(top: 12),
                                    decoration: const BoxDecoration(
                                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.lock, size: 16, color: Color(0xFF5D5F5F)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Authorized access only. All authorization attempts and ledger transactions are cryptographically logged.',
                                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF5D5F5F), height: 1.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Security Metadata Grid Matrix
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text('PROTOCOL', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF5D5F5F))),
                                        const SizedBox(height: 2),
                                        Text('TLS 1.3', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1B1C1C))),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 28, color: const Color(0xFFE5E7EB)),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text('ENCRYPTION', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF5D5F5F))),
                                        const SizedBox(height: 2),
                                        Text('AES-256', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1B1C1C))),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 28, color: const Color(0xFFE5E7EB)),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text('REGION', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF5D5F5F))),
                                        const SizedBox(height: 2),
                                        Text('IN-BLR', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1B1C1C))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBF9F8),
                        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF5D5F5F),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('DHARA CORE v2.4.1', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF5D5F5F), fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Text('TERMINAL #09', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF5D5F5F), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevSuperAdminList() {
    if (_isLoadingDevUsers) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF1B1C1C))),
      );
    }
    if (_devSuperAdmins.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('No active super admins found')),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF9F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _devSuperAdmins.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
        itemBuilder: (context, index) {
          final u = _devSuperAdmins[index];
          return ListTile(
            dense: true,
            leading: const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF1B1C1C),
              child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 14),
            ),
            title: Text(u['name'] ?? 'Super Admin', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF1B1C1C))),
            subtitle: Text(u['phone'] ?? '', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF5D5F5F))),
            trailing: const Icon(Icons.login, size: 16, color: Color(0xFF1B1C1C)),
            onTap: () => _devSuperAdminLogin(u['phone']),
          );
        },
      ),
    );
  }
}
