import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../widgets/custom_page_header.dart';
import '../utils/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _panelBackground = StitchColors.background;
  static const Color _textPrimary = StitchColors.textPrimary;
  static const Color _textSecondary = StitchColors.textSecondary;
  static const Color _cardBorder = Color(0xFFE5E5E5);

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
      appBar: CustomAppBar(
        title: 'Settings',
        icon: Icons.settings_rounded,
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: Text(
              'POS',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF71717A),
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
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
      padding: const EdgeInsets.all(16),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_user != null) _buildSubscriptionCard(),
            _buildShopIdentitySummary(),
            const SizedBox(height: 16),
            _buildSectionHeader('STORE MANAGEMENT'),
            const SizedBox(height: 8),
            _buildGroupedSection([
              _SettingsRowData(
                icon: Icons.storefront_outlined,
                title: 'Shop Profile',
                subtitle: 'Logo, Address, Contact Info',
                onTap: () => _open(const ShopSetupScreen()),
              ),
              _SettingsRowData(
                icon: Icons.print_outlined,
                title: 'Printer Settings',
                subtitle: 'Bluetooth & Paper Size (58mm / 80mm)',
                badge: _isPrinterConnected ? 'Connected' : 'Disconnected',
                badgeBg: _isPrinterConnected
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFF4F4F5),
                badgeColor: _isPrinterConnected
                    ? const Color(0xFF166534)
                    : const Color(0xFF52525B),
                badgeBorder: _isPrinterConnected
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFD4D4D8),
                onTap: () => _open(const PrinterSetupScreen()),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSectionHeader('BILLING & PAYMENTS'),
            const SizedBox(height: 8),
            _buildGroupedSection([
              _SettingsRowData(
                icon: Icons.payments_outlined,
                title: 'Payment Modes',
                subtitle: 'Cash, Cards, UPI, QR',
                onTap: () => _open(const PaymentModesScreen()),
              ),
              _SettingsRowData(
                icon: Icons.receipt_long_outlined,
                title: 'Tax Settings',
                subtitle: 'GST, VAT, Service Charge',
                onTap: () => _open(const TaxSettingsScreen()),
              ),
              _SettingsRowData(
                icon: Icons.local_offer_outlined,
                title: 'Token Prefix Settings',
                subtitle: 'Customize Order Numbers',
                onTap: () => _open(const TokenPrefixScreen()),
              ),
            ]),
            const SizedBox(height: 20),
            _buildSectionHeader('SYSTEM & SECURITY'),
            const SizedBox(height: 8),
            _buildGroupedSection([
              _SettingsRowData(
                icon: Icons.logout_rounded,
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
            ]),
            const SizedBox(height: 24),
            _buildFooter(),
            const SizedBox(height: 24),
          ],
        ).animate().fadeIn(duration: 300.ms),
      ],
    );
  }

  Widget _buildSubscriptionCard() {
    final isTrial = _user?.accountStatus == 'trial';
    String planName = _user?.approvedPlan ?? 'Trial Plan Active';
    if (isTrial) planName = 'Trial Plan Active';
    final statusStr = _user?.accountStatus.toUpperCase() ?? 'TRIAL';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF111111)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SUBSCRIPTION',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFA1A1AA),
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF3F3F46)),
                ),
                child: Text(
                  statusStr,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE4E4E7),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            planName,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          if (_user?.trialEnd != null)
            Text(
              'Valid until: ${_user!.trialEnd!.split('T')[0]}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: const Color(0xFFA1A1AA),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () => _open(const SubscriptionPlansScreen()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF111111),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Plans / Upgrade',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopIdentitySummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              size: 20,
              color: Color(0xFF27272A),
            ),
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _shopData?.id != null ? 'ID: ${_shopData!.id}' : 'ID: --',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE4E4E7)),
            ),
            child: Text(
              _user?.approvedPlan ?? 'Premium Plan',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF3F3F46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF71717A),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildGroupedSection(List<_SettingsRowData> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _buildSettingsRow(rows[i]),
            if (i < rows.length - 1)
              const Divider(height: 1, thickness: 1, color: _cardBorder),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingsRow(_SettingsRowData data) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE4E4E7)),
              ),
              child: Icon(
                data.icon,
                size: 18,
                color: data.danger ? const Color(0xFFDC2626) : const Color(0xFF3F3F46),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: data.danger ? const Color(0xFFDC2626) : _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    data.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (data.badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: data.badgeBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: data.badgeBorder ?? Colors.transparent),
                ),
                child: Text(
                  data.badge!,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: data.badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFFA1A1AA),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            'POS Version 2.4.0 (Build 842)',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: const Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'LEDGER PROTOCOL • OPERATIONAL',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFA1A1AA),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _SettingsRowData {
  const _SettingsRowData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.badgeBg,
    this.badgeColor,
    this.badgeBorder,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeBg;
  final Color? badgeColor;
  final Color? badgeBorder;
  final bool danger;
  final VoidCallback? onTap;
}

