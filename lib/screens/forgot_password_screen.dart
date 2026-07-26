import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';
import 'password_login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _bg = Color(0xFFEEF2FF);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _softBg = Color(0xFFF1F5F9);

  int _step = 0;
  bool _isLoading = false;

  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String _phone = '';
  int _secondsLeft = 60;
  Timer? _timer;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _timer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) { t.cancel(); }
      else { if (mounted) setState(() => _secondsLeft--); }
    });
  }

  void _nextStep() {
    _animCtrl.reset();
    setState(() => _step++);
    _animCtrl.forward();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length != 10) { _showError('Please enter a valid 10-digit phone number'); return; }
    setState(() => _isLoading = true);
    try {
      await RestaurantApi.instance.forgotPasswordRequest(phone);
      _phone = phone;
      _startTimer();
      _nextStep();
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) { _showError('Please enter the 6-digit OTP'); return; }
    _nextStep();
  }

  Future<void> _resetPassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();
    if (newPass.length < 6) { _showError('Password must be at least 6 characters'); return; }
    if (newPass != confirm) { _showError('Passwords do not match'); return; }
    setState(() => _isLoading = true);
    try {
      await RestaurantApi.instance.resetPassword(
        phone: _phone,
        otp: _otpCtrl.text.trim(),
        newPassword: newPass,
      );
      _showSuccess();
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_secondsLeft > 0) return;
    setState(() => _isLoading = true);
    try {
      await RestaurantApi.instance.forgotPasswordRequest(_phone);
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent!'), backgroundColor: Color(0xFF10B981)));
      }
    } catch (e) { _showError(e.toString().replaceAll('Exception: ', '')); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)));
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 44)),
              const SizedBox(height: 20),
              Text('Password Reset!', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: _textPrimary)),
              const SizedBox(height: 10),
              Text('Password reset successful!\nLogin with your new password.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: _textSecondary, height: 1.5)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PasswordLoginScreen()), (r) => false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text('Go to Login',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        Positioned(top: 0, left: 0, right: 0,
          height: MediaQuery.of(context).size.height * 0.42,
          child: Container(color: _bg)),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 20),
                onPressed: () {
                  if (_step == 0) { Navigator.pop(context); }
                  else { _animCtrl.reset(); setState(() => _step--); _animCtrl.forward(); }
                }),
              const Spacer(),
              Row(children: List.generate(3, (i) {
                final done = i < _step; final active = i == _step;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(left: 6),
                  width: active ? 24 : 8, height: 8,
                  decoration: BoxDecoration(
                    color: (done || active) ? _primary : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4)));
              })),
            ])),
          const SizedBox(height: 20),
          _buildTopIcon(),
          const SizedBox(height: 28),
          Expanded(child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(36), topRight: Radius.circular(36)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))]),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(36), topRight: Radius.circular(36)),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(32, 36, 32, MediaQuery.of(context).viewInsets.bottom + 32),
                child: FadeTransition(opacity: _fadeAnim,
                  child: SlideTransition(position: _slideAnim, child: _buildStepContent())))))),
        ])),
      ]));
  }

  Widget _buildTopIcon() {
    final icons = [Icons.phone_android_rounded, Icons.lock_open_rounded, Icons.lock_reset_rounded];
    final labels = ['Forgot Password', 'Verify OTP', 'New Password'];
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.18), blurRadius: 32, spreadRadius: 4, offset: const Offset(0, 10))]),
        child: Icon(icons[_step], size: 56, color: _primary)),
      const SizedBox(height: 12),
      Text(labels[_step], style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary)),
    ]);
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _buildStep0();
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildStep0() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Enter your registered phone number',
        style: GoogleFonts.inter(fontSize: 15, color: _textSecondary, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      _inputField(controller: _phoneCtrl, hintText: 'Phone Number',
        prefix: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text('+91', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary))),
        keyboardType: TextInputType.phone,
        formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
      const SizedBox(height: 32),
      _primaryButton(label: 'Send OTP', onTap: _sendOtp),
      const SizedBox(height: 20),
      Center(child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: 'Remember your password? ', style: GoogleFonts.inter(color: _textSecondary)),
          TextSpan(text: 'Login', style: GoogleFonts.inter(color: _primary, fontWeight: FontWeight.w700)),
        ])))),
    ]);
  }

  Widget _buildStep1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: 'OTP sent to ', style: GoogleFonts.inter(fontSize: 15, color: _textSecondary)),
        TextSpan(text: '+91 $_phone', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
      ]), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      _inputField(controller: _otpCtrl, hintText: '6-digit OTP',
        prefix: const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
          child: Icon(Icons.pin_rounded, color: Color(0xFF94A3B8), size: 20)),
        keyboardType: TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        letterSpacing: 8),
      const SizedBox(height: 12),
      Center(child: _secondsLeft > 0
        ? Text.rich(TextSpan(children: [
            TextSpan(text: 'Resend OTP in ', style: GoogleFonts.inter(color: _textSecondary, fontSize: 13)),
            TextSpan(text: '${_secondsLeft}s', style: GoogleFonts.inter(color: _primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ]))
        : GestureDetector(onTap: _resendOtp,
            child: Text('Resend OTP', style: GoogleFonts.inter(color: _primary, fontWeight: FontWeight.w700, fontSize: 13)))),
      const SizedBox(height: 32),
      _primaryButton(label: 'Verify OTP', onTap: _verifyOtp),
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Create a strong new password',
        style: GoogleFonts.inter(fontSize: 15, color: _textSecondary, height: 1.5), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      _inputField(controller: _newPassCtrl, hintText: 'New Password',
        prefix: const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
          child: Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20)),
        obscure: _obscureNew,
        suffix: IconButton(
          icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF94A3B8), size: 20),
          onPressed: () => setState(() => _obscureNew = !_obscureNew))),
      const SizedBox(height: 16),
      _inputField(controller: _confirmPassCtrl, hintText: 'Confirm Password',
        prefix: const Padding(padding: EdgeInsets.symmetric(horizontal: 16),
          child: Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20)),
        obscure: _obscureConfirm,
        suffix: IconButton(
          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF94A3B8), size: 20),
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm))),
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Text('Minimum 6 characters', style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
      ]),
      const SizedBox(height: 32),
      _primaryButton(label: 'Reset Password', onTap: _resetPassword),
    ]);
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hintText,
    required Widget prefix,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    Widget? suffix,
    double letterSpacing = 0,
  }) {
    return Container(
      decoration: BoxDecoration(color: _softBg, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        prefix,
        Expanded(child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          obscureText: obscure,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary, letterSpacing: letterSpacing),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8), letterSpacing: 0),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 18)))),
        if (suffix != null) suffix,
      ]));
  }

  Widget _primaryButton({required String label, required VoidCallback onTap}) {
    return SizedBox(width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 4, shadowColor: _primary.withValues(alpha: 0.45)),
        child: _isLoading
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700))));
  }
}
