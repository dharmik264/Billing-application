import 'package:flutter/material.dart';
import '../services/restaurant_api.dart';

class TokenPrefixScreen extends StatefulWidget {
  const TokenPrefixScreen({super.key});

  @override
  State<TokenPrefixScreen> createState() => _TokenPrefixScreenState();
}

class _TokenPrefixScreenState extends State<TokenPrefixScreen> {
  bool _isLoading = false;
  final TextEditingController _prefixController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final billSettings = RestaurantApi.instance.shopData?.billSettings ?? {};
    _prefixController.text =
        billSettings['token_prefix']?.toString() ?? 'Token ';
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.arrow_back,
                              size: 19, color: Color(0xFF555555)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Token Prefix',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1F2937),
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
                        const Text('Custom Token Prefix',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const Text(
                            'This prefix will be prepended to the generated token numbers. Default is "Token ".',
                            style: TextStyle(fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _prefixController,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            hintText: 'e.g. T- or B-',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes',
                              style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.05),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
