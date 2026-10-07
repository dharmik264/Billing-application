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
  static const Color _bgCanvas = Color(0xFFFBF9F8);
  static const Color _brandDark = Color(0xFF111111);
  static const Color _mutedText = Color(0xFF71717A);
  static const Color _brandBorder = Color(0xFFE5E5E5);

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
            const SnackBar(
              content: Text('Payment modes updated successfully'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shop data not loaded')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgCanvas,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Top Navigation Bar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _brandBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: _brandDark),
                    ),
                  ),
                  Text(
                    'Payment Modes',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _brandDark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded, size: 20, color: _mutedText),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Select which payment methods customers can use at checkout.'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Scrollable Main Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Header & Explanation
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _brandDark,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Select Accepted Payments',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _brandDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Text(
                        'Choose which payment methods customers can use at checkout.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _mutedText,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Option 1: Both (Cash & Online)
                    _buildPaymentOptionCard(
                      title: 'Both (Cash & Online)',
                      subtitle: 'Accept all payment methods',
                      value: 'Both',
                      icon: Icons.account_balance_wallet_outlined,
                      isDefault: true,
                    ),

                    const SizedBox(height: 12),

                    // Option 2: Cash Only
                    _buildPaymentOptionCard(
                      title: 'Cash Only',
                      subtitle: 'Accept only physical cash',
                      value: 'Cash',
                      icon: Icons.payments_outlined,
                    ),

                    const SizedBox(height: 12),

                    // Option 3: Online Only
                    _buildPaymentOptionCard(
                      title: 'Online Only',
                      subtitle: 'Accept UPI, Cards & NetBanking',
                      value: 'Online',
                      icon: Icons.qr_code_scanner_rounded,
                    ),

                    const SizedBox(height: 20),

                    // Notice Banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _brandBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF52525B)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Payment terminal settings will auto-sync with counter pos devices instantly upon saving.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF52525B),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Primary Action CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _save,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Standardized 6-Tab Bottom Navigation Bar
            Container(
              height: 60,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _brandBorder)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navTab(Icons.storefront_outlined, 'Home', active: false),
                  _navTab(Icons.confirmation_number_outlined, 'Token', active: false),
                  _navTab(Icons.groups_outlined, 'Customers', active: false),
                  _navTab(Icons.inventory_2_outlined, 'Items', active: false),
                  _navTab(Icons.bar_chart_rounded, 'Analytics', active: false),
                  _navTab(Icons.settings_rounded, 'Settings', active: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    bool isDefault = false,
  }) {
    final bool isSelected = _selectedMode == value;

    return InkWell(
      onTap: _isLoading ? null : () => setState(() => _selectedMode = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _brandDark : _brandBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon Badge
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _brandBorder),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? _brandDark : const Color(0xFF52525B),
              ),
            ),
            const SizedBox(width: 14),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _brandDark,
                          ),
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFD4D4D8)),
                          ),
                          child: Text(
                            'DEFAULT',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3F3F46),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _mutedText,
                    ),
                  ),
                ],
              ),
            ),

            // Radio Circle
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? _brandDark : Colors.white,
                shape: BoxShape.circle,
                border: isSelected ? null : Border.all(color: const Color(0xFFD4D4D8)),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTab(IconData icon, String label, {required bool active}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 20,
          color: active ? _brandDark : const Color(0xFFA1A1AA),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active ? _brandDark : const Color(0xFFA1A1AA),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 3),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: _brandDark,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

