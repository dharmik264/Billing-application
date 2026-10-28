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
import 'trial_expired_screen.dart';

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
         final status = userMap['account_status']?.toString() ?? '';
         final trialEndStr = userMap['trial_end']?.toString() ?? '';
         await prefs.setString('account_status', status);
         await prefs.setString('trial_end', trialEndStr);
         
         if (userMap.containsKey('permissions') && userMap['permissions'] != null) {
           await prefs.setString('permissions', jsonEncode(userMap['permissions']));
         }

         final trialEnd = DateTime.tryParse(trialEndStr);
         final isExpired = status == 'expired' || 
             (status == 'trial' && trialEnd != null && DateTime.now().isAfter(trialEnd));
         if (isExpired && mobile != '9999999999' && mobile != '6351559728') {
           await prefs.setString('account_status', 'expired');
           if (mounted) {
             Navigator.of(context).pushReplacement(
               MaterialPageRoute(builder: (context) => TrialExpiredScreen(phone: mobile, shopName: userMap['shop_name'])),
             );
           }
           return;
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
        if (errMsg.toLowerCase().contains('trial has expired') || errMsg.contains('TRIAL_EXPIRED')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('account_status', 'expired');
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => TrialExpiredScreen(phone: mobile)),
          );
          return;
        }
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
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF5F3F3),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: isKeyboardOpen ? 2 : 12,
              ),
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
                    if (Navigator.canPop(context))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFBF9F8),
                          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1B1C1C)),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),

                    // Body scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isKeyboardOpen ? 6 : 24,
                        ),
                        child: Column(
                          children: [
                            if (!isKeyboardOpen) ...[
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
                            ],

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isKeyboardOpen) ...[
                                  const Icon(
                                    Icons.storefront_outlined,
                                    size: 20,
                                    color: Color(0xFF1B1C1C),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  'Welcome',
                                  style: GoogleFonts.inter(
                                    fontSize: isKeyboardOpen ? 18 : 24,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1B1C1C),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            if (!isKeyboardOpen) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Log in to securely manage your shop.',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF5D5F5F),
                                ),
                              ),
                            ],
                            SizedBox(height: isKeyboardOpen ? 8 : 24),

                            // Form Fields
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MOBILE NUMBER',
                                  style: GoogleFonts.inter(
                                    fontSize: isKeyboardOpen ? 10 : 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF5D5F5F),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: isKeyboardOpen ? 3 : 6),
                                Container(
                                  height: isKeyboardOpen ? 42 : 48,
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
                                          textInputAction: TextInputAction.next,
                                          scrollPadding: EdgeInsets.only(bottom: isKeyboardOpen ? 16 : 90),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                          ],
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF1B1C1C),
                                          ),
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
                                SizedBox(height: isKeyboardOpen ? 8 : 16),

                                Text(
                                  'SECURITY PASSWORD',
                                  style: GoogleFonts.inter(
                                    fontSize: isKeyboardOpen ? 10 : 11,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF5D5F5F),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: isKeyboardOpen ? 3 : 6),
                                Container(
                                  height: isKeyboardOpen ? 42 : 48,
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
                                          textInputAction: TextInputAction.done,
                                          onSubmitted: (_) => _login(),
                                          scrollPadding: EdgeInsets.only(bottom: isKeyboardOpen ? 16 : 90),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF1B1C1C),
                                          ),
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
                                SizedBox(height: isKeyboardOpen ? 4 : 8),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                    ),
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.inter(
                                        fontSize: isKeyboardOpen ? 12 : 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF5D5F5F),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: isKeyboardOpen ? 8 : 20),

                                SizedBox(
                                  width: double.infinity,
                                  height: isKeyboardOpen ? 44 : 48,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1B1C1C),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                              fontSize: isKeyboardOpen ? 15 : 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),

                          ],
                        ),
                      ),
                    ),

                    // Bottom Navigation Footer (Hidden when keyboard is open)
                    if (!isKeyboardOpen)
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
