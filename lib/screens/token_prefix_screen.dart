import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';

class TokenPrefixScreen extends StatefulWidget {
  const TokenPrefixScreen({super.key});

  @override
  State<TokenPrefixScreen> createState() => _TokenPrefixScreenState();
}

class _TokenPrefixScreenState extends State<TokenPrefixScreen> {
  static const Color _bgCanvas = Color(0xFFFBF9F8);
  static const Color _brandDark = Color(0xFF111111);
  static const Color _mutedText = Color(0xFF71717A);
  static const Color _brandBorder = Color(0xFFE5E5E5);

  bool _isLoading = false;
  final TextEditingController _prefixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final billSettings = RestaurantApi.instance.shopData?.billSettings ?? {};
    _prefixController.text = billSettings['token_prefix']?.toString() ?? 'T-';
    _prefixController.addListener(_onPrefixChanged);
  }

  void _onPrefixChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _prefixController
      ..removeListener(_onPrefixChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final shop = RestaurantApi.instance.shopData;
      if (shop != null) {
        final newSettings = Map<String, dynamic>.from(shop.billSettings ?? {});
        newSettings['token_prefix'] = _prefixController.text.trim();

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
              content: Text('Token prefix updated successfully'),
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
    final currentPrefix = _prefixController.text.trim().isEmpty
        ? 'T-'
        : _prefixController.text.trim();

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
                    'Token Prefix',
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
                          content: Text('Custom token prefix will be prepended to all printed token tickets.'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Scrollable Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Title & Description
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
                          'Token Configuration',
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
                        'Set custom prefix for order token numbers generated at checkout.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _mutedText,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Input Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _brandBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOKEN PREFIX',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _mutedText,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF9F8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _brandBorder),
                            ),
                            child: TextField(
                              controller: _prefixController,
                              enabled: !_isLoading,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _brandDark,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. T-, TK-, or ORD-',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFFA1A1AA),
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: const Icon(
                                  Icons.tag_rounded,
                                  color: Color(0xFF71717A),
                                  size: 18,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Live Token Number Preview Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _brandBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.visibility_outlined,
                                size: 16,
                                color: _brandDark,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'LIVE TOKEN PREVIEW',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _brandDark,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE5E5E5)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${currentPrefix}101',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: _brandDark,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sample Token Ticket #101',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: _mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'This prefix will be printed on all order slips, token tickets, and receipts.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _mutedText,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save CTA Button
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

