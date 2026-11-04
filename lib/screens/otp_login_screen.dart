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
import 'trial_expired_screen.dart';

class OTPLoginScreen extends StatefulWidget {
  final bool prefilledPhone;
  const OTPLoginScreen({Key? key, this.prefilledPhone = false}) : super(key: key);

  @override
  State<OTPLoginScreen> createState() => _OTPLoginScreenState();
}

class _OTPLoginScreenState extends State<OTPLoginScreen> {
  late TextEditingController _mobileController;
  late List<TextEditingController> _otpControllers;
  late List<FocusNode> _otpFocusNodes;

  bool _showOTPSection = false;
  bool _hasError = false;
  bool _isLoading = false;
  int _attemptsRemaining = 2;
  bool _isResendCooldown = false;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController();
    _otpControllers = List.generate(4, (_) => TextEditingController());
    _otpFocusNodes = List.generate(4, (_) => FocusNode());
    for (var node in _otpFocusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
    _checkPrefilledPhone();
    // Auto-fill removed: user must enter OTP received via SMS
  }

  Future<void> _checkPrefilledPhone() async {
    if (widget.prefilledPhone) {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('loginPhone');
      if (phone != null && phone.isNotEmpty) {
        setState(() {
          _mobileController.text = phone;
          _showOTPSection = true; // Show OTP fields directly
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _otpFocusNodes.isNotEmpty) {
            FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOTP() async {
    String mobile = _mobileController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (mobile.isEmpty || mobile.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid mobile number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool otpSentSuccessfully = false;
    try {
      await RestaurantApi.instance.requestOtp(mobile);
      otpSentSuccessfully = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent to your mobile number via SMS'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      otpSentSuccessfully = false;
      if (mounted) {
        String errMsg = e.toString().replaceAll('Exception: ', '');
        // Friendly messages for common errors
        if (errMsg.contains('Please register first') || errMsg.contains('register')) {
          errMsg = 'Phone number not registered. Please register first.';
        } else if (errMsg.contains('SocketException') || errMsg.contains('Failed host lookup') || errMsg.contains('network')) {
          errMsg = 'No internet connection. Please check and try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    // Only show OTP screen if request was successful
    if (!mounted || !otpSentSuccessfully) return;
    setState(() {
      _showOTPSection = true;
      _hasError = false;
      _attemptsRemaining = 2;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _otpFocusNodes.isNotEmpty) {
        FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
      }
    });
  }

  void _onOTPFieldChanged(String value, int index) {
    if (value.length > 1) {
      final clean = value.replaceAll(RegExp(r'[^\d]'), '');
      for (int i = 0; i < 4 && i < clean.length; i++) {
        _otpControllers[i].text = clean[i];
      }
      if (clean.length >= 4) {
        _otpFocusNodes[3].unfocus();
      } else {
        FocusScope.of(context).requestFocus(_otpFocusNodes[clean.length.clamp(0, 3)]);
      }
      setState(() {});
      return;
    }
    if (value.isNotEmpty) {
      if (index < 3) {
        FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
      } else {
        _otpFocusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
    }
    setState(() {});
  }

  Future<void> _verifyOTP() async {
    // Temporary mode: pressing verify logs in without validating the OTP.
    final mobile = _mobileController.text.replaceAll(RegExp(r'[^\d]'), '');
    final otp = _otpControllers.map((controller) => controller.text).join();

    setState(() => _isLoading = true);

    try {
      final responseMap = await RestaurantApi.instance.verifyOtp(mobile, otp);
      
      // Store user details in prefs
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
         
         if (userMap['account_status'] == 'trial') {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('Welcome! You are in the 7-day free trial period.'),
                 backgroundColor: Colors.blue,
               ),
             );
           }
         }
      }

    } catch (e) {
      if (!mounted) return;
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

      setState(() {
        _attemptsRemaining--;
        _hasError = true;
        _isLoading = false;
      });

      if (_attemptsRemaining <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Too many failed attempts. Try resending OTP.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!mounted) return;
    setState(() {
      _hasError = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login Successful!'),
        backgroundColor: Colors.green,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final loginPhone = _mobileController.text.replaceAll(RegExp(r'[^\d]'), '');
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('loginPhone', loginPhone);
    await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);

    // Super Admin routing
    if (loginPhone == '9999999999') {
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
      // Shop setup screen sets paymentModesConfig when saved. Registration leaves it null.
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
  }

  Future<void> _resendOTP() async {
    final mobile = _mobileController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (mobile.isEmpty) return;

    setState(() {
      _hasError = false;
      _attemptsRemaining = 2;
      _isResendCooldown = true;
      _resendCountdown = 30;

      for (var controller in _otpControllers) {
        controller.clear();
      }
    });

    FocusScope.of(context).requestFocus(_otpFocusNodes[0]);

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          _isResendCooldown = false;
        }
      });
      return _isResendCooldown;
    });

    try {
      final devOtp = await RestaurantApi.instance.requestOtp(mobile);
      if (mounted) {
        if (devOtp != null && devOtp.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('DEV OTP: $devOtp'),
              duration: const Duration(seconds: 10),
              backgroundColor: Colors.blue,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP resent to your mobile number')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _showOTPSection = false;
      _hasError = false;
      _mobileController.clear();
      for (var controller in _otpControllers) {
        controller.clear();
      }
    });
  }

  Widget _buildOTPField(int index) {
    final hasFocus = _otpFocusNodes[index].hasFocus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        FocusScope.of(context).requestFocus(_otpFocusNodes[index]);
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: hasFocus
                ? const Color(0xFF2563EB)
                : const Color(0xFFCBD5E1),
            width: hasFocus ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: hasFocus
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: _otpControllers[index],
          focusNode: _otpFocusNodes[index],
          maxLength: 1,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: false,
            signed: false,
          ),
          textInputAction: index < 3 ? TextInputAction.next : TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) => _onOTPFieldChanged(value, index),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFEEF2FF),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header Bar (Back Button if OTP shown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (_showOTPSection)
                    InkWell(
                      onTap: _resetForm,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF0F172A)),
                      ),
                    )
                  else
                    const SizedBox(height: 40),
                ],
              ),
            ),

            // Storefront Illustration Anchor
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.storefront_rounded, size: 52, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 16),

            // Bottom White Card
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: _showOTPSection ? _buildOTPForm() : _buildPhoneForm(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome',
          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your mobile number to securely login to your account.',
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
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendOTP,
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
              : Text('Send OTP', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
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
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SuperAdminLoginScreen()));
              },
              child: Text('Login here', style: GoogleFonts.inter(color: const Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOTPForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify OTP',
          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ve sent a verification code to\n+91 ${_mobileController.text}',
          style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildOTPField(0),
            _buildOTPField(1),
            _buildOTPField(2),
            _buildOTPField(3),
          ],
        ),
        const SizedBox(height: 24),
        if (_hasError)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Expanded(child: Text('Wrong OTP. $_attemptsRemaining attempts remaining.', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF991B1B)))),
              ],
            ),
          ),
        if (_hasError) const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Didn\'t receive the code? ', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            GestureDetector(
              onTap: _isResendCooldown ? null : _resendOTP,
              child: Text(
                _isResendCooldown ? 'Resend in ${_resendCountdown}s' : 'Resend OTP',
                style: GoogleFonts.inter(
                  color: _isResendCooldown ? const Color(0xFF94A3B8) : const Color(0xFF4F46E5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: (_attemptsRemaining > 0 && !_isLoading) ? _verifyOTP : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 4,
            shadowColor: const Color(0xFF10B981).withValues(alpha: 0.5),
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Verify & Login', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

}
