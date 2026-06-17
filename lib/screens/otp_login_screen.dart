import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/restaurant_api.dart';
import 'shop_setup_screen.dart';
import 'dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OTPLoginScreen extends StatefulWidget {
  const OTPLoginScreen({Key? key}) : super(key: key);

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

    try {
      await RestaurantApi.instance.requestOtp(mobile);
    } catch (_) {
      // Temporary frontend mode continues even when the backend is offline.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;
    setState(() {
      _showOTPSection = true;
      _hasError = false;
      _attemptsRemaining = 2;
    });

    FocusScope.of(context).requestFocus(_otpFocusNodes[0]);
  }

  void _onOTPFieldChanged(String value, int index) {
    if (value.length == 1 && value.isNotEmpty) {
      if (index < 3) {
        FocusScope.of(context).requestFocus(_otpFocusNodes[index + 1]);
      }
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_otpFocusNodes[index - 1]);
    }
  }

  Future<void> _verifyOTP() async {
    // Temporary mode: pressing verify logs in without validating the OTP.
    final mobile = _mobileController.text.replaceAll(RegExp(r'[^\d]'), '');
    final otp = _otpControllers.map((controller) => controller.text).join();

    setState(() => _isLoading = true);

    try {
      await RestaurantApi.instance.verifyOtp(mobile, otp);
    } catch (e) {
      if (!mounted) return;
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
            content: Text('Connection failed. Server offline or ADB reverse needed.'),
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
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('loginPhone', _mobileController.text.replaceAll(RegExp(r'[^\d]'), ''));
    await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);
    bool isSetupComplete = prefs.getBool('isSetupComplete') ?? false;
    try {
      final shop = await RestaurantApi.instance.fetchShop(forceRefresh: true);
      // 'My Restaurant' is the default name in backend. If changed, setup is done.
      if (shop.name.isNotEmpty && shop.name != 'My Restaurant') {
        isSetupComplete = true;
        await prefs.setBool('isSetupComplete', true);
      }
    } catch (_) {}

    if (mounted) {
      if (isSetupComplete) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
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
      await RestaurantApi.instance.requestOtp(mobile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent to your mobile number')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed. Server offline or ADB reverse needed.'),
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
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _otpFocusNodes[index].hasFocus
              ? const Color(0xFF2563EB)
              : const Color(0xFFDDDDDD),
          width: _otpFocusNodes[index].hasFocus ? 2 : 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        maxLength: 1,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (value) => _onOTPFieldChanged(value, index),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF0F4FF), Color(0xFFFAF5FF)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Center(
              child: Container(
                width: 360,
                decoration: BoxDecoration(
                  color: const Color(0xFAFFFFFF),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Back Button
                    if (_showOTPSection)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xCCFFFFFF),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(
                                color: const Color(0xFFDDDDDD),
                                width: 0.5,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back),
                              iconSize: 17,
                              color: const Color(0xFF555555),
                              onPressed: _resetForm,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                    // Header Icon
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.storefront,
                            size: 34,
                            color: Color(0xFFEA580C),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Title
                    const Text(
                      'Login with Mobile Number',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    // Subtitle
                    const Text(
                      'Enter your details to continue',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Mobile Number Input Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MOBILE NUMBER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFDDDDDD),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: Color(0xFFEEEEEE),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.only(right: 8),
                                    child: const Text(
                                      '+91 ▾',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF555555),
                                      ),
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
                                    decoration: const InputDecoration(
                                      hintText: '98450 12345',
                                      border: InputBorder.none,
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Send OTP Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _sendOTP,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.send, size: 17),
                                    SizedBox(width: 8),
                                    Text(
                                      'Send OTP',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // OTP Section
                    if (_showOTPSection) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            // OTP Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'ENTER 4-DIGIT OTP',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF6B7280),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _isResendCooldown ? null : _resendOTP,
                                  child: Text(
                                    _isResendCooldown
                                        ? 'Resend in ${_resendCountdown}s'
                                        : 'Resend OTP',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: _isResendCooldown
                                          ? const Color(0xFFBBBBBB)
                                          : const Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // OTP Input Fields
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildOTPField(0),
                                const SizedBox(width: 10),
                                _buildOTPField(1),
                                const SizedBox(width: 10),
                                _buildOTPField(2),
                                const SizedBox(width: 10),
                                _buildOTPField(3),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Error Message
                            if (_hasError)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  border: Border.all(
                                    color: const Color(0xFFFECACA),
                                    width: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error,
                                      size: 16,
                                      color: Color(0xFFDC2626),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Wrong OTP. $_attemptsRemaining attempts remaining.',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF991B1B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 14),
                            // Verify OTP Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: (_attemptsRemaining > 0 && !_isLoading)
                                    ? _verifyOTP
                                    : null,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shield_outlined,
                                            size: 17,
                                            color: _attemptsRemaining > 0
                                                ? Colors.white
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Verify OTP & Login',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: _attemptsRemaining > 0
                                                  ? Colors.white
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_showOTPSection) const SizedBox(height: 14),
                    // Security Info
                    if (!_showOTPSection)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: Color(0xFFAAAAAA),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Secure login using OTP',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    // Footer Links
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Terms of Service',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            Text(
                              ' · ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFCCCCCC),
                              ),
                            ),
                            Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
