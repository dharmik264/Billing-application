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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              color: const Color(0xFFEEF2FF),
              child: SafeArea(
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      right: 16,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Dev Mode', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5))),
                          Switch(
                            value: _isDevMode,
                            activeTrackColor: const Color(0xFF4F46E5),
                            onChanged: (val) {
                              setState(() => _isDevMode = val);
                              if (val && _devUsers.isEmpty) {
                                _fetchDevUsers();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.storefront_rounded, size: 64, color: Color(0xFF4F46E5)),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(32, 40, 32, MediaQuery.of(context).viewInsets.bottom + 24),
                  child: _isDevMode 
                      ? _buildDevUserList() 
                      : _buildLoginForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text('+91', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
              ),
              Container(width: 1, height: 24, color: const Color(0xFFCBD5E1)),
              Expanded(
                child: TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A), letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Enter Phone Number',
                    hintStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8), letterSpacing: 0),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF94A3B8),
                  size: 20,
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
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 4,
            shadowColor: const Color(0xFF4F46E5).withValues(alpha: 0.5),
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Login', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
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

  Widget _buildDevUserList() {
    if (_isLoadingDevUsers) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(color: Colors.deepPurple),
      );
    }
    if (_devUsers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Text('No active users found'),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 350),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _devUsers.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final u = _devUsers[index];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            title: Text(u['name'] ?? 'User', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Text(u['phone'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
            trailing: const Icon(Icons.login, size: 18, color: Color(0xFF94A3B8)),
            onTap: () => _performDevLogin(u['phone']),
          );
        },
      ),
    );
  }
}
