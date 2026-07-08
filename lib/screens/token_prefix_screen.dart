import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/restaurant_api.dart';

class TokenPrefixScreen extends StatefulWidget {
  const TokenPrefixScreen({super.key});

  @override
  State<TokenPrefixScreen> createState() => _TokenPrefixScreenState();
}

class _TokenPrefixScreenState extends State<TokenPrefixScreen> {
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _softBorder = Color(0xFFE2E8F0);

  bool _isLoading = false;
  final TextEditingController _prefixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final billSettings = RestaurantApi.instance.shopData?.billSettings ?? {};
    _prefixController.text = billSettings['token_prefix']?.toString() ?? 'Token ';
  }

  @override
  void dispose() {
    _prefixController.dispose();
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
              const SnackBar(content: Text('Token prefix updated')));
          Navigator.pop(context);
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
                        'Token Prefix',
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
                        Text('Custom Token Prefix',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
                        const SizedBox(height: 6),
                        Text(
                          'This prefix will be prepended to all generated token numbers. Default is "Token ".',
                          style: GoogleFonts.inter(fontSize: 13, color: _textSecondary),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _softBorder, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: TextField(
                            controller: _prefixController,
                            enabled: !_isLoading,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. T- or Bill-',
                              hintStyle: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: const Icon(Icons.tag_rounded,
                                  color: Color(0xFF94A3B8), size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
                          ),
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
}
