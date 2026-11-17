import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/restaurant_api.dart';
import 'shop_setup_screen.dart';
import 'main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'registration_screen.dart';
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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // Header Bar (Back button if can pop)
                if (Navigator.canPop(context))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, size: 22, color: Color(0xFF1B1C1C)),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ),

                // Body scrollable content directly on the gradient
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: isKeyboardOpen ? 6 : 24,
                    ),
                    child: Column(
                      children: [
                        if (!isKeyboardOpen) ...[
                          // Monochromatic Brand Icon Anchor
                          Container(
                            width: 60,
                            height: 60,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              size: 30,
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
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5D5F5F),
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: isKeyboardOpen ? 3 : 6),
                            Container(
                              height: isKeyboardOpen ? 42 : 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(9),
                                        bottomLeft: Radius.circular(9),
                                      ),
                                      border: Border(right: BorderSide(color: Color(0xFFCBD5E1))),
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
                                        hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
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
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF5D5F5F),
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: isKeyboardOpen ? 3 : 6),
                            Container(
                              height: isKeyboardOpen ? 42 : 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 12, right: 8),
                                    child: Icon(Icons.lock_outline, size: 18, color: Color(0xFF64748B)),
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
                                        hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 18,
                                      color: const Color(0xFF64748B),
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
                                    color: const Color(0xFF1E40AF),
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 2,
                                  shadowColor: Colors.black26,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('New user? ', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF475569))),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const RegistrationScreen()));
                          },
                          child: Text('Register here', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E40AF), decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
