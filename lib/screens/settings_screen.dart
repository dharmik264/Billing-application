import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'password_login_screen.dart';
import 'printer_setup_screen.dart';
import 'shop_setup_screen.dart';
import 'payment_modes_screen.dart';
import 'tax_settings_screen.dart';
import 'token_prefix_screen.dart';
import 'subscription_plans_screen.dart';
import '../services/printer_service.dart';
import '../services/restaurant_api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _panelBackground = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _softBorder = Color(0xFFE2E8F0);
  static const Color _danger = Color(0xFFEF4444);
  ApiShopData? _shopData;
  ApiUser? _user;
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
      final user = await RestaurantApi.instance.fetchProfile();
      final isConnected = await PrinterService.instance.isConnected;

      if (!mounted) return;
      setState(() {
        _shopData = shop;
        _user = user;
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
                if (_user != null) _subscriptionCard(),
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
                        await prefs.clear();
                        await RestaurantApi.instance.clearTokens();
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const PasswordLoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'POS Version 2.4.0 (Build 842)',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'DESIGNED WITH \u2665 FOR GASTRONOMY',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFCBD5E1),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: _softBorder, width: 1.0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subscriptionCard() {
    bool isTrial = _user?.accountStatus == 'trial';
    String planName = _user?.approvedPlan ?? 'Unknown Plan';
    if (isTrial) planName = 'Trial Plan Active';
    String statusStr = _user?.accountStatus.toUpperCase() ?? 'PENDING';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subscription',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusStr,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            planName,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          if (_user?.trialEnd != null)
            Text(
              'Valid until: ',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _open(const SubscriptionPlansScreen()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4F46E5),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View Plans / Upgrade'),
          ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.restaurant_menu,
                size: 28, color: Color(0xFFEA580C)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shopData?.name ?? 'Shop Name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _shopData?.id != null ? 'ID: ${_shopData!.id}' : 'Loading...',
                  style: GoogleFonts.inter(fontSize: 13, color: _textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Premium Plan',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF166534),
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
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                _settingsRow(rows[index]),
                if (index != rows.length - 1)
                  const Divider(
                      height: 1.0, thickness: 1.0, color: Color(0xFFF1F5F9)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: data.iconBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, size: 20, color: data.iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: data.danger ? _danger : _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 13, color: _textSecondary, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            if (data.badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: data.badgeBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data.badge!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: data.badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFCBD5E1)),
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
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.8,
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
