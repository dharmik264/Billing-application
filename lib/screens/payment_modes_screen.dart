// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';

class PaymentModesScreen extends StatefulWidget {
  const PaymentModesScreen({super.key});

  @override
  State<PaymentModesScreen> createState() => _PaymentModesScreenState();
}

class _PaymentModesScreenState extends State<PaymentModesScreen> {
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _softBorder = Color(0xFFE2E8F0);

  bool _isLoading = false;
  String _selectedMode = 'Both';

  @override
  void initState() {
    super.initState();
    _selectedMode = RestaurantApi.instance.shopData?.paymentModesConfig ?? 'Both';
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final shop = RestaurantApi.instance.shopData;
      if (shop != null) {
        await RestaurantApi.instance.saveShop(
          ApiShopDraft(
            name: shop.name,
            tagline: shop.tagline,
            phone: shop.phone,
            alternatePhone: shop.alternatePhone,
            address: shop.address,
            email: shop.email,
            gstin: shop.gstin,
            upiId: shop.upiId,
            logoUrl: shop.logoUrl,
            qrUrl: shop.qrUrl,
            paymentModesConfig: _selectedMode,
            billSettings: shop.billSettings,
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment modes updated')));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Shop data not loaded')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _primary.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_rounded, size: 20, color: _textPrimary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Payment Modes',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Select Accepted Payments',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
                        const SizedBox(height: 6),
                        Text(
                          'Choose which payment methods customers can use at checkout.',
                          style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
                        ),
                        const SizedBox(height: 24),
                        _paymentOptionCard(
                          title: 'Both (Cash & Online)',
                          subtitle: 'Accept all payment methods',
                          value: 'Both',
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                        const SizedBox(height: 12),
                        _paymentOptionCard(
                          title: 'Cash Only',
                          subtitle: 'Accept only physical cash',
                          value: 'Cash',
                          icon: Icons.payments_rounded,
                        ),
                        const SizedBox(height: 12),
                        _paymentOptionCard(
                          title: 'Online Only',
                          subtitle: 'Accept UPI, Cards & NetBanking',
                          value: 'Online',
                          icon: Icons.qr_code_scanner_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('Save Changes',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.05),
                child: const Center(child: CircularProgressIndicator(color: _primary)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _paymentOptionCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final bool isSelected = _selectedMode == value;

    return InkWell(
      onTap: _isLoading ? null : () => setState(() => _selectedMode = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primary : _softBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? _primary.withValues(alpha: 0.1)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? _primary : const Color(0xFF94A3B8),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? const Icon(Icons.check_circle_rounded, color: _primary, size: 24, key: ValueKey('checked'))
                  : const Icon(Icons.radio_button_unchecked_rounded, color: Color(0xFFCBD5E1), size: 24, key: ValueKey('unchecked')),
            ),
          ],
        ),
      ),
    );
  }
}
