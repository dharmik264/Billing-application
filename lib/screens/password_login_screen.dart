import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/restaurant_api.dart';
import 'shop_setup_screen.dart';
import 'main_screen.dart';
import 'super_admin_main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'registration_screen.dart';
import 'super_admin_login_screen.dart';
import 'forgot_password_screen.dart';
import '../utils/app_constants.dart';

class PasswordLoginScreen extends StatefulWidget {
  const PasswordLoginScreen({Key? key}) : super(key: key);

  @override
  State<PasswordLoginScreen> createState() => _PasswordLoginScreenState();
}

class _PasswordLoginScreenState extends State<PasswordLoginScreen> {
  late TextEditingController _mobileController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  bool _isDevMode = false;
  List<dynamic> _devUsers = [];
  bool _isLoadingDevUsers = false;

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController();
    _passwordController = TextEditingController();
  }

  Future<void> _fetchDevUsers() async {
    setState(() => _isLoadingDevUsers = true);
    try {
      final users = await RestaurantApi.instance.fetchDevUsers();
      setState(() {
        _devUsers = users.where((u) => u['is_superuser'] != true).toList();
      });
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (errMsg.contains('SocketException') || errMsg.contains('Failed host lookup') || errMsg.contains('TimeoutException')) {
          errMsg = 'Unable to connect to server. Please try again.';
        } else {
          errMsg = 'Failed to load dev users. Error: $errMsg';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoadingDevUsers = false);
    }
  }

  Future<void> _performDevLogin(String phone) async {
    setState(() => _isLoading = true);
    try {
      final responseMap = await RestaurantApi.instance.devLogin(phone);
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('loginPhone', phone);
      await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);
      
      if (responseMap.containsKey('user')) {
         final userMap = responseMap['user'];
         await prefs.setString('account_status', userMap['account_status'] ?? '');
         await prefs.setString('trial_end', userMap['trial_end'] ?? '');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dev Login failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _devSuperAdminBypass() async {
    setState(() => _isLoading = true);
    try {
      final users = await RestaurantApi.instance.fetchDevUsers();
      final superAdmins = users.where((u) => u['is_superuser'] == true).toList();
      if (superAdmins.isEmpty) throw Exception('No Super Admin found');
      
      await RestaurantApi.instance.devLogin(superAdmins.first['phone']);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('loginPhone', superAdmins.first['phone']);
      await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SuperAdminMainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Super Admin Bypass failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    String mobile = _mobileController.text.replaceAll(RegExp(r'[^\d]'), '');
    String password = _passwordController.text;
    
    if (mobile.isEmpty || mobile.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid mobile number')),
      );
      return;
    }
    
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final responseMap = await RestaurantApi.instance.login(mobile, password);
      
      final prefs = await SharedPreferences.getInstance();
      if (responseMap.containsKey('user')) {
         final userMap = responseMap['user'];
         await prefs.setString('account_status', userMap['account_status'] ?? '');
         await prefs.setString('trial_end', userMap['trial_end'] ?? '');
         
         if (userMap.containsKey('permissions') && userMap['permissions'] != null) {
           await prefs.setString('permissions', jsonEncode(userMap['permissions']));
         }
      }

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Successful!'), backgroundColor: Colors.green),
      );

      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('loginPhone', mobile);
      await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);

      if (mobile == '9999999999') {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SuperAdminMainScreen()),
            (route) => false,
          );
        }
        return;
      }

      bool isSetupComplete = prefs.getBool('isSetupComplete') ?? false;
      try {
        final shop = await RestaurantApi.instance.fetchShop(forceRefresh: true);
        if (shop.paymentModesConfig != null && shop.paymentModesConfig!.isNotEmpty) {
          isSetupComplete = true;
          await prefs.setBool('isSetupComplete', true);
        }
      } catch (_) {}

      if (mounted) {
        if (isSetupComplete) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ShopSetupScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString().replaceAll('Exception: ', '');
        if (errMsg.contains('SocketException') || errMsg.contains('Failed host lookup')) {
          errMsg = 'No internet connection. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFEEF2FF),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                    children: [
                      // Top Hero / Header Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Dev Mode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5))),
                                    Switch(
                                      value: _isDevMode,
                                      activeTrackColor: const Color(0xFF4F46E5),
                                      onChanged: (val) {
                                        setState(() => _isDevMode = val);
                                        if (val) {
                                          RestaurantApi.instance.setCustomBaseUrl('http://127.0.0.1:8000/api');
                                          if (_devUsers.isEmpty) {
                                            _fetchDevUsers();
                                          }
                                        } else {
                                          RestaurantApi.instance.setCustomBaseUrl(null);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                    blurRadius: 25,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.storefront_rounded, size: 54, color: Color(0xFF4F46E5)),
                            ),
                          ],
                        ),
                      ),
                      
                      // Bottom Card Form Container
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
                          child: _buildLoginForm(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isDevMode) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.developer_mode, size: 18, color: Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Local Server Active (http://127.0.0.1:8000/api)',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF3730A3)),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoadingDevUsers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)))),
            )
          else if (_devUsers.isNotEmpty) ...[
            Text('Quick Select Dev User:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _devUsers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final u = _devUsers[index];
                  final name = u['name'] ?? u['phone'] ?? 'User';
                  return ActionChip(
                    avatar: const Icon(Icons.person, size: 14, color: Color(0xFF4F46E5)),
                    label: Text(name.toString(), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFFF1F5F9),
                    onPressed: () {
                      _mobileController.text = u['phone']?.toString() ?? '';
                      _performDevLogin(u['phone']?.toString() ?? '');
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
        Text(
          'Welcome Back!',
          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Log in to securely manage your shop.',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: StitchColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: StitchColors.border, width: 1),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('+91', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: StitchColors.textPrimary)),
              ),
              Container(width: 1, height: 20, color: StitchColors.border),
              Expanded(
                child: TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: StitchColors.textPrimary, letterSpacing: 1.0),
                  decoration: InputDecoration(
                    hintText: 'Enter Phone Number',
                    hintStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: StitchColors.textMuted, letterSpacing: 0),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: StitchColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: StitchColors.border, width: 1),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Icon(Icons.lock_outline, color: StitchColors.textMuted, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: StitchColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: StitchColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: StitchColors.textMuted,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
            ),
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: StitchColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: StitchColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Login', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New user? ', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const RegistrationScreen()));
              },
              child: Text('Register here', style: GoogleFonts.inter(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Super Admin? ', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            GestureDetector(
              onTap: () {
                if (_isDevMode) {
                  _devSuperAdminBypass();
                } else {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SuperAdminLoginScreen()));
                }
              },
              child: Text('Login here', style: GoogleFonts.inter(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }
}
