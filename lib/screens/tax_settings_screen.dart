import 'package:flutter/material.dart';
import '../services/restaurant_api.dart';

class TaxSettingsScreen extends StatefulWidget {
  const TaxSettingsScreen({super.key});

  @override
  State<TaxSettingsScreen> createState() => _TaxSettingsScreenState();
}

class _TaxSettingsScreenState extends State<TaxSettingsScreen> {
  bool _isLoading = false;
  final TextEditingController _taxPercentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final billSettings = RestaurantApi.instance.shopData?.billSettings ?? {};
    _taxPercentController.text =
        (billSettings['tax_percent'] ?? 0.0).toString();
  }

  @override
  void dispose() {
    _taxPercentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final shop = RestaurantApi.instance.shopData;
      if (shop != null) {
        final newSettings = Map<String, dynamic>.from(shop.billSettings ?? {});
        newSettings['tax_percent'] =
            double.tryParse(_taxPercentController.text) ?? 0.0;

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
              const SnackBar(content: Text('Tax settings updated')));
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
                        'Tax Settings',
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
                        const Text('Default Tax Percentage (%)',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text(
                          'Set the default GST or tax percentage to apply on all tokens. Leave as 0.0 to disable automatic tax calculation.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                          ),
                          child: TextField(
                            controller: _taxPercentController,
                            enabled: !_isLoading,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1F2937),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'e.g. 5.0',
                              hintStyle: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: Icon(Icons.percent_rounded,
                                  color: Color(0xFF6B7280), size: 20),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                            ),
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
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
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
