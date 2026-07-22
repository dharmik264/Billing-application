import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/restaurant_api.dart';

class SuperAdminPaymentSettingsScreen extends StatefulWidget {
  const SuperAdminPaymentSettingsScreen({super.key});

  @override
  State<SuperAdminPaymentSettingsScreen> createState() =>
      _SuperAdminPaymentSettingsScreenState();
}

class _SuperAdminPaymentSettingsScreenState
    extends State<SuperAdminPaymentSettingsScreen> {
  final TextEditingController _upiController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _currentQrUrl;
  Uint8List? _newQrBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await RestaurantApi.instance.fetchSystemSettings();
      if (mounted) {
        setState(() {
          _upiController.text = settings.paymentUpiId ?? '';
          _currentQrUrl = settings.paymentQrCode;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _pickQrImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _newQrBytes = bytes;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      String? base64Image;
      if (_newQrBytes != null) {
        base64Image = base64Encode(_newQrBytes!);
      }

      await RestaurantApi.instance.updateSystemSettings(
        upiId: _upiController.text.trim(),
        base64QrImage: base64Image,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment QR Code and UPI ID updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _loadSettings();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Payment QR & UPI Settings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded,
                            color: Color(0xFF4F46E5), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Super Admin Payment Details: Set the QR Code image and UPI ID that users see during plan subscription payment.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF3730A3),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'PAYMENT UPI ID',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _upiController,
                    decoration: InputDecoration(
                      hintText: 'e.g. merchant@upi or 9999999999@ybl',
                      prefixIcon: const Icon(Icons.payment_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'PAYMENT QR CODE IMAGE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                              )
                            ],
                          ),
                          child: _newQrBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.memory(_newQrBytes!,
                                      fit: BoxFit.cover),
                                )
                              : (_currentQrUrl != null &&
                                      _currentQrUrl!.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(
                                        RestaurantApi.instance
                                            .getMediaUrl(_currentQrUrl!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(
                                            Icons.qr_code_2_rounded,
                                            size: 80,
                                            color: Color(0xFF94A3B8)),
                                      ),
                                    )
                                  : const Icon(Icons.qr_code_2_rounded,
                                      size: 80, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickQrImage,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: Text(
                            _newQrBytes != null || _currentQrUrl != null
                                ? 'Change QR Image'
                                : 'Upload QR Image',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Save Payment Settings',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
