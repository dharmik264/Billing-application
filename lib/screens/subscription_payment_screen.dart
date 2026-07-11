import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';

class SubscriptionPaymentScreen extends StatefulWidget {
  final ApiSubscriptionPlan plan;
  final String billingCycle;

  const SubscriptionPaymentScreen({super.key, required this.plan, required this.billingCycle});

  @override
  State<SubscriptionPaymentScreen> createState() => _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState extends State<SubscriptionPaymentScreen> {
  final TextEditingController _utrController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  ApiSystemSettings? _settings;

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
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load payment details: $e')));
      }
    }
  }

  Future<void> _submitPayment() async {
    final utr = _utrController.text.trim();
    if (utr.isEmpty || utr.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid Transaction ID')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await RestaurantApi.instance.submitSubscriptionPayment(widget.plan.id, utr, widget.billingCycle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment submitted! Pending verification.')));
        Navigator.pop(context);
        Navigator.pop(context); // Go back to settings
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double amount = widget.billingCycle == 'monthly' ? widget.plan.priceMonthly : widget.plan.priceYearly;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Payment', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 20)),
        backgroundColor: const Color(0xFFEEF2FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Complete Your Payment', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Scan the QR code below using any UPI app to pay for the ${widget.plan.name} (${widget.billingCycle}) plan.', style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  
                  // Plan Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.plan.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                            Text(widget.billingCycle.toUpperCase(), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                          ],
                        ),
                        Text('₹${amount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF4F46E5))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // QR Code Section
                  Center(
                    child: _settings?.paymentQrCode != null && _settings!.paymentQrCode!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(_settings!.paymentQrCode!, width: 200, height: 200, fit: BoxFit.cover),
                          )
                        : Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(16)),
                            alignment: Alignment.center,
                            child: const Icon(Icons.qr_code_2, size: 64, color: Color(0xFF94A3B8)),
                          ),
                  ),
                  const SizedBox(height: 16),
                  if (_settings?.paymentUpiId != null && _settings!.paymentUpiId!.isNotEmpty)
                    Text('UPI ID: ${_settings!.paymentUpiId}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)), textAlign: TextAlign.center),
                  
                  const SizedBox(height: 48),
                  
                  // UTR Input
                  Text('Enter Transaction ID (UTR)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _utrController,
                    decoration: InputDecoration(
                      hintText: 'e.g., 230918239012',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5))),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Submit Payment', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              ),
            ),
    );
  }
}
