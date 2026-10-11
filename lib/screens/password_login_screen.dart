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
  

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController();
    _passwordController = TextEditingController();
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
                          if (Navigator.canPop(context))
                            IconButton(
                              icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1B1C1C)),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          else
                            const SizedBox(width: 20),
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
                          const SizedBox(width: 20),
                        ],
                      ),
                    ),

                    // Body scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Monochromatic Brand Icon Anchor
                            Container(
                              width: 56,
                              height: 56,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: const Icon(
                                Icons.storefront_outlined,
                                size: 28,
                                color: Color(0xFF1B1C1C),
                              ),
                            ),

                            Text(
                              'Welcome Back!',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1B1C1C),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Log in to securely manage your shop.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: const Color(0xFF5D5F5F),
                              ),
                            ),
                            const SizedBox(height: 24),


                            // Form Fields
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MOBILE NUMBER',
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF5F3F3),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(7),
                                            bottomLeft: Radius.circular(7),
                                          ),
                                          border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
                                        ),
                                        child: Text(
                                          '+91',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1B1C1C),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _mobileController,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                          ],
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1B1C1C)),
                                          decoration: InputDecoration(
                                            hintText: 'Enter Phone Number',
                                            hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5D5F5F)),
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Text(
                                  'SECURITY PASSWORD',
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
                                        padding: EdgeInsets.only(left: 12, right: 8),
                                        child: Icon(Icons.lock_outline, size: 18, color: Color(0xFF5D5F5F)),
                                      ),
                                      Expanded(
                                        child: TextField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF1B1C1C)),
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
                                          size: 18,
                                          color: const Color(0xFF5D5F5F),
                                        ),
                                        onPressed: () {
                                          setState(() => _obscurePassword = !_obscurePassword);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

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
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF5D5F5F),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1B1C1C),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text('Login', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Terminal POS info ledger
                            Container(
                              padding: const EdgeInsets.only(top: 12),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Terminal POS #04',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF5D5F5F)),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1B1C1C),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Store Node Online',
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF5D5F5F)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Navigation Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F3F3),
                        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('New user? ', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5D5F5F))),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const RegistrationScreen()));
                                },
                                child: Text('Register here', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1B1C1C), decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Super Admin? ', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5D5F5F))),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SuperAdminLoginScreen()));
                                },
                                child: Text('Login here', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1B1C1C), decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
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
}

