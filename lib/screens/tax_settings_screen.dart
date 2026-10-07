import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  static const Color _bgCanvas = Color(0xFFFBF9F8);
  static const Color _brandDark = Color(0xFF111111);
  static const Color _mutedText = Color(0xFF71717A);
  static const Color _brandBorder = Color(0xFFE5E7EB);

  bool _isLoading = false;
  final TextEditingController _taxPercentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final billSettings = RestaurantApi.instance.shopData?.billSettings ?? {};
    _taxPercentController.text = (billSettings['tax_percent'] ?? 0.0).toString();
    _taxPercentController.addListener(_onTaxChanged);
  }

  void _onTaxChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _taxPercentController
      ..removeListener(_onTaxChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final shop = RestaurantApi.instance.shopData;
      if (shop != null) {
        final newSettings = Map<String, dynamic>.from(shop.billSettings ?? {});
        newSettings['tax_percent'] = double.tryParse(_taxPercentController.text) ?? 0.0;

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
            paymentModesConfig: shop.paymentModesConfig,
            billSettings: newSettings,
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tax settings updated successfully'),
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
    final currentVal = double.tryParse(_taxPercentController.text.trim()) ?? 0.0;

    return Scaffold(
      backgroundColor: _bgCanvas,
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Top App Bar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: _bgCanvas,
                border: Border(bottom: BorderSide(color: Color(0x99E5E7EB))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _brandBorder),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: _brandDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Tax Settings',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _brandDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, size: 20, color: _mutedText),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Default tax percentage applies automatically during checkout.'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Main Content Scroll Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Title & Description
                    Text(
                      'Default Tax Percentage (%)',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _brandDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set the default GST/tax percentage for all tokens. Set to 0.0 to disable.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _mutedText,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Main Tax Percentage Input Card
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _brandBorder),
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
                          // % Badge
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF3F4F6)),
                            ),
                            child: Text(
                              '%',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _mutedText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Numeric Input Field
                          Expanded(
                            child: TextField(
                              controller: _taxPercentController,
                              enabled: !_isLoading,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _brandDark,
                                letterSpacing: -0.3,
                              ),
                              decoration: InputDecoration(
                                hintText: '0.0',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD1D5DB),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),

                          // Reset Button
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() => _taxPercentController.text = '0.0'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Reset',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _mutedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Quick Select Rate Presets Header
                    Text(
                      'STANDARD PRESETS',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _mutedText,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Presets Grid (4 columns)
                    Row(
                      children: [
                        Expanded(child: _presetCard('0.0%', 'Exempt', 0.0, currentVal)),
                        const SizedBox(width: 8),
                        Expanded(child: _presetCard('5.0%', 'GST', 5.0, currentVal)),
                        const SizedBox(width: 8),
                        Expanded(child: _presetCard('12.0%', 'Standard', 12.0, currentVal)),
                        const SizedBox(width: 8),
                        Expanded(child: _presetCard('18.0%', 'Higher', 18.0, currentVal)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Informational Notice Callout Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _brandBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: _mutedText,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tax calculation is applied automatically during checkout. This rate can be manually modified or overridden on individual items if authorized.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _mutedText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Container Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                                  fontSize: 16,
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
                border: Border(top: BorderSide(color: Color(0xCCE5E7EB))),
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

  Widget _presetCard(String percentLabel, String subtitle, double targetVal, double currentVal) {
    final bool isSelected = (currentVal - targetVal).abs() < 0.01;

    return InkWell(
      onTap: _isLoading ? null : () => setState(() => _taxPercentController.text = targetVal.toStringAsFixed(1)),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _brandDark : _brandBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              percentLabel,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _brandDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: _mutedText,
              ),
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

