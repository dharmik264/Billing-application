import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/restaurant_api.dart';
import 'otp_login_screen.dart';
import 'password_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _shopNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    String phone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (phone.length > 10 && phone.startsWith('91')) {
      phone = phone.substring(phone.length - 10);
    }
    
    try {
      final response = await RestaurantApi.instance.registerUser(
        name: _nameController.text.trim(),
        phone: phone,
        shopName: _shopNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      if (!mounted) return;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('loginPhone', phone);
      
      final devOtp = response['otp']?.toString();
      if (!mounted) return;
      if (devOtp != null && devOtp.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration successful! Your OTP is: $devOtp'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 15),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Registration successful, OTP sent.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => OTPLoginScreen(
                prefilledPhone: true,
                prefilledOtp: devOtp,
              ),
            ),
          );
        }
      });
      
    } catch (e) {
      if (!mounted) return;
      String errMsg = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException: ', '');
      if (errMsg.contains('SocketException') || errMsg.contains('Failed host lookup') || errMsg.contains('TimeoutException')) {
        errMsg = 'Unable to connect to server. Please check internet connection.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                          IconButton(
                            icon: const Icon(Icons.arrow_back, size: 20, color: Color(0xFF1B1C1C)),
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (context) => const PasswordLoginScreen()),
                                );
                              }
                            },
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
                          const SizedBox(width: 32),
                        ],
                      ),
                    ),

                    // Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Brand Icon & Header
                              Container(
                                width: 48,
                                height: 48,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: const Icon(
                                  Icons.storefront,
                                  size: 26,
                                  color: Color(0xFF1B1C1C),
                                ),
                              ),
                              Text(
                                'Create your Account',
                                style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1B1C1C),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Start your 7-day free trial today',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF5D5F5F),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Form Fields
                              _buildInputField(
                                controller: _nameController,
                                placeholder: 'Full Name',
                                icon: Icons.person_outline,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                controller: _phoneController,
                                placeholder: 'Mobile Number',
                                icon: Icons.smartphone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  final phone = (v ?? '').replaceAll(RegExp(r'[^\d]'), '');
                                  if (phone.length != 10) return 'Enter a valid 10-digit number';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                controller: _shopNameController,
                                placeholder: 'Shop / Business Name',
                                icon: Icons.store_outlined,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Shop name is required' : null,
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                controller: _emailController,
                                placeholder: 'Email (Optional)',
                                icon: Icons.mail_outline,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) {
                                  if (v != null && v.isNotEmpty) {
                                    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Password Field
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Icon(Icons.lock_outline, size: 20, color: Color(0xFF5D5F5F)),
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
                                        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1B1C1C)),
                                        decoration: InputDecoration(
                                          hintText: 'Password',
                                          hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5D5F5F)),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.zero,
                                          errorStyle: const TextStyle(height: 0, fontSize: 0),
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
                              const SizedBox(height: 20),

                              // Primary CTA
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _register,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B1C1C),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text('Register & Start Trial', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Matrix Trust Proof Point Grid
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        child: Column(
                                          children: [
                                            Text('No credit card', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF5D5F5F))),
                                            const SizedBox(height: 2),
                                            Text('Instant Setup', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1B1C1C))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(width: 1, height: 36, color: const Color(0xFFE5E7EB)),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        child: Column(
                                          children: [
                                            Text('Free cloud backup', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF5D5F5F))),
                                            const SizedBox(height: 2),
                                            Text('7 Days Unrestricted', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1B1C1C))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBF9F8),
                        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already registered? ', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5D5F5F))),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => const PasswordLoginScreen()),
                              );
                            },
                            child: Text(
                              'Login here',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1B1C1C),
                                decoration: TextDecoration.underline,
                              ),
                            ),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String placeholder,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(icon, size: 20, color: const Color(0xFF5D5F5F)),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              validator: validator,
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1B1C1C)),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF5D5F5F)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(right: 12),
                errorStyle: const TextStyle(height: 0, fontSize: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

