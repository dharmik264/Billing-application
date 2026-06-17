import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'otp_login_screen.dart';
import 'printer_setup_screen.dart';
import 'shop_setup_screen.dart';
import 'payment_modes_screen.dart';
import 'tax_settings_screen.dart';
import 'token_prefix_screen.dart';
import '../services/printer_service.dart';
import '../services/restaurant_api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _panelBackground = Color(0xFFF5F6FA);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _softBorder = Color(0xFFEEEEEE);
  static const Color _danger = Color(0xFFDC2626);
  ApiShopData? _shopData;
  bool _isPrinterConnected = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final shop = RestaurantApi.instance.shopData ??
          await RestaurantApi.instance.fetchShop();
      final isConnected = await PrinterService.instance.isConnected;

      if (!mounted) return;
      setState(() {
        _shopData = shop;
        _isPrinterConnected = isConnected;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panelBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _buildPanel(),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _profileCard(),
                _settingsSection(
                  title: 'Store Management',
                  rows: [
                    _SettingsRowData(
                      icon: Icons.storefront_outlined,
                      iconBackground: const Color(0xFFEFF6FF),
                      iconColor: _primary,
                      title: 'Shop Profile',
                      subtitle: 'Logo, Address, Contact Info',
                      onTap: () => _open(const ShopSetupScreen()),
                    ),
                    _SettingsRowData(
                      icon: Icons.print_outlined,
                      iconBackground: const Color(0xFFFFF7ED),
                      iconColor: const Color(0xFFEA580C),
                      title: 'Printer Settings',
                      subtitle: 'Bluetooth, Thermal, LAN',
                      badge: _isPrinterConnected ? 'Connected' : 'Disconnected',
                      badgeBackground: _isPrinterConnected
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      badgeColor: _isPrinterConnected
                          ? const Color(0xFF166534)
                          : const Color(0xFF991B1B),
                      onTap: () => _open(const PrinterSetupScreen()),
                    ),
                  ],
                ),
                _settingsSection(
                  title: 'Billing & Payments',
                  rows: [
                    _SettingsRowData(
                      icon: Icons.account_balance_wallet_outlined,
                      iconBackground: const Color(0xFFF5F3FF),
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Payment Modes',
                      subtitle: 'Cash, Cards, UPI, QR',
                      onTap: () => _open(const PaymentModesScreen()),
                    ),
                    _SettingsRowData(
                      icon: Icons.receipt_long_outlined,
                      iconBackground: const Color(0xFFF0FDF4),
                      iconColor: const Color(0xFF16A34A),
                      title: 'Tax Settings',
                      subtitle: 'GST, VAT, Service Charge',
                      onTap: () => _open(const TaxSettingsScreen()),
                    ),
                    _SettingsRowData(
                      icon: Icons.local_offer_outlined,
                      iconBackground: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      title: 'Token Prefix Settings',
                      subtitle: 'Customize Order Numbers',
                      onTap: () => _open(const TokenPrefixScreen()),
                    ),
                  ],
                ),
                _settingsSection(
                  title: 'System & Security',
                  rows: [

                    _SettingsRowData(
                      icon: Icons.logout,
                      iconBackground: const Color(0xFFFEF2F2),
                      iconColor: _danger,
                      title: 'Logout',
                      subtitle: 'Sign out from this device',
                      danger: true,
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('isLoggedIn');
                        await prefs.remove('loginPhone');
                        await prefs.remove('loginTimestamp');
                        await prefs.remove('accessToken');
                        await prefs.remove('refreshToken');
                        await prefs.remove('isSetupComplete');
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const OTPLoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'POS Version 2.4.0 (Build 842)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
                const SizedBox(height: 2),
                const Text(
                  'DESIGNED WITH \u2665 FOR GASTRONOMY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFCCCCCC),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _softBorder, width: 0.5)),
      ),
      child: const Row(
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _softBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant_menu,
                size: 24, color: Color(0xFFEA580C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shopData?.name ?? 'Shop Name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _shopData?.id != null ? 'ID: ${_shopData!.id}' : 'Loading...',
                  style: const TextStyle(fontSize: 12, color: _textSecondary),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Premium Plan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsSection({
    required String title,
    required List<_SettingsRowData> rows,
  }) {
    return Column(
      children: [
        _sectionLabel(title),
        const SizedBox(height: 8),
        Container(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _softBorder, width: 0.5),
          ),
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                _settingsRow(rows[index]),
                if (index != rows.length - 1)
                  const Divider(
                      height: 0.5, thickness: 0.5, color: Color(0xFFF0F0F0)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsRow(_SettingsRowData data) {
    return InkWell(
      onTap: data.onTap ?? () => _showSnackBar('${data.title} opened'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: data.iconBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, size: 17, color: data.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: data.danger ? _danger : _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            if (data.badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: data.badgeBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data.badge!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: data.badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFBBBBBB)),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsRowData {
  const _SettingsRowData({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeBackground = Colors.transparent,
    this.badgeColor = Colors.transparent,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color badgeBackground;
  final Color badgeColor;
  final bool danger;
  final VoidCallback? onTap;
}
