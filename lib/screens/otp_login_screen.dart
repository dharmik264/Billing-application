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

  bool _isDevMode = false;
  List<dynamic> _devUsers = [];
  bool _isLoadingDevUsers = false;

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController();
    _otpControllers = List.generate(4, (_) => TextEditingController());
    _otpFocusNodes = List.generate(4, (_) => FocusNode());
    _checkPrefilledPhone();
  }

  Future<void> _fetchDevUsers() async {
    setState(() => _isLoadingDevUsers = true);
    try {
      final users = await RestaurantApi.instance.fetchDevUsers();
      setState(() {
        // Exclude super admins from shop owner login list
        _devUsers = users.where((u) => u['is_superuser'] != true).toList();
      });
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (errMsg.contains('SocketException') || errMsg.contains('Failed host lookup')) {
          errMsg = 'Unable to connect to server. Please check your internet connection.';
        } else {
          errMsg = 'Failed to load dev users.';
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

  Future<void> _checkPrefilledPhone() async {
    if (widget.prefilledPhone) {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('loginPhone');
      if (phone != null && phone.isNotEmpty) {
        setState(() {
          _mobileController.text = phone;
          _showOTPSection = true; // Show OTP fields directly
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
      final devOtp = await RestaurantApi.instance.requestOtp(mobile);
      otpSentSuccessfully = true;
      if (devOtp != null && devOtp.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('DEV OTP: $devOtp'),
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.blue,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent to your mobile number'),
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
      final responseMap = await RestaurantApi.instance.verifyOtp(mobile, otp);
      
      // Store user details in prefs
      final prefs = await SharedPreferences.getInstance();
      if (responseMap.containsKey('user')) {
         final userMap = responseMap['user'];
         await prefs.setString('account_status', userMap['account_status'] ?? '');
         await prefs.setString('trial_end', userMap['trial_end'] ?? '');
         
         if (userMap.containsKey('permissions') && userMap['permissions'] != null) {
           await prefs.setString('permissions', jsonEncode(userMap['permissions']));
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
            content: Text(e.toString().replaceAll('Exception: ', '')),
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
      // 'My Restaurant' is the default name in backend. If changed, setup is done.
      if (shop.name.isNotEmpty && shop.name != 'My Restaurant') {
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top half (Pastel Indigo Background)
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
                    // Back Button (If OTP shown)
                    if (_showOTPSection)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: InkWell(
                          onTap: _resetForm,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                    
                    // Dev Mode Toggle (If not OTP)
                    if (!_showOTPSection)
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

                    // Storefront Illustration
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
          
          // Bottom half (White Card)
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
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                  child: _isDevMode && !_showOTPSection 
                      ? _buildDevUserList() 
                      : (_showOTPSection ? _buildOTPForm() : _buildPhoneForm()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneForm() {
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
        const SizedBox(height: 20),
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
