// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../services/restaurant_api.dart';

class PaymentModesScreen extends StatefulWidget {
  const PaymentModesScreen({super.key});

  @override
  State<PaymentModesScreen> createState() => _PaymentModesScreenState();
}

class _PaymentModesScreenState extends State<PaymentModesScreen> {
  bool _isLoading = false;
  String _selectedMode = 'Both';

  @override
  void initState() {
    super.initState();
    _selectedMode =
        RestaurantApi.instance.shopData?.paymentModesConfig ?? 'Both';
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
                        'Payment Modes',
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
                        const Text('Select Accepted Payments',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const Text(
                          'Select your accepted payment methods to show during checkout.',
                          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 24),
                        _paymentOptionCard(
                          title: 'Both (Cash & Online)',
                          subtitle: 'Accept all payment methods',
                          value: 'Both',
                          icon: Icons.account_balance_wallet_outlined,
                        ),
                        const SizedBox(height: 12),
                        _paymentOptionCard(
                          title: 'Cash Only',
                          subtitle: 'Accept only physical cash',
                          value: 'Cash',
                          icon: Icons.payments_outlined,
                        ),
                        const SizedBox(height: 12),
                        _paymentOptionCard(
                          title: 'Online Only',
                          subtitle: 'Accept UPI, Cards & NetBanking',
                          value: 'Online',
                          icon: Icons.qr_code_scanner,
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

  Widget _paymentOptionCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final bool isSelected = _selectedMode == value;
    const Color activeColor = Color(0xFF2563EB); // Modern Blue
    final Color borderColor = isSelected ? activeColor : const Color(0xFFE5E7EB);
    final Color bgColor = isSelected ? activeColor.withValues(alpha: 0.05) : Colors.white;

    return InkWell(
      onTap: _isLoading ? null : () => setState(() => _selectedMode = value),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : const Color(0xFF6B7280),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: activeColor,
                size: 24,
              )
            else
              const Icon(
                Icons.circle_outlined,
                color: Color(0xFFD1D5DB),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
