import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/restaurant_api.dart';
import '../widgets/bill_receipt_widget.dart';
import '../utils/app_constants.dart';
import 'main_screen.dart';
import 'dart:math' as math;
import 'dart:typed_data';

class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  static const Color _panelBackground = AppColors.slate50;
  static const Color _primary = AppColors.indigo600;
  static const Color _textPrimary = AppColors.slate900;
  static const Color _textSecondary = AppColors.slate500;
  static const Color _border = AppColors.slate200;
  static const Color _softBorder = AppColors.slate100;
  static const double _panelWidth = 360;

  final TextEditingController _shopNameController =
      TextEditingController(text: 'Tasty Bites Bistro');
  final TextEditingController _taglineController =
      TextEditingController(text: 'Authentic Italian Flavors');
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _alternatePhoneController =
      TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _thankYouMessageController =
      TextEditingController(text: 'Thank you for visiting!');
  final TextEditingController _customFooterNoteController =
      TextEditingController();
  final TextEditingController _termsAndConditionsController =
      TextEditingController();

  final Map<String, dynamic> _billSettings = {
    'autoGenerateInvoice': true,
    'showInvoiceNumber': true,
    'showDateTime': true,
    'showCashierName': true,
    'showCustomerName': true,
    'showCustomerMobile': true,
    'showItemName': true,
    'showQuantity': true,
    'showUnitPrice': true,
    'showTotalPrice': true,
    'showSubtotal': true,
    'showDiscount': true,
    'showGstTax': true,
    'showRoundOff': true,
    'showGrandTotal': true,
    'showPaymentMethod': true,
    'showQrCode': true,
    'showUpiId': true,
  };

  // Payment mode: 'Cash' | 'Online / UPI' | 'Both'
  String _selectedPaymentMode = 'Both';

  Uint8List? _logoBytes;
  Uint8List? _qrBytes;
  bool _saving = false;
  bool _isLoading = true;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _shopNameController.addListener(_refreshPreview);
    _taglineController.addListener(_refreshPreview);
    _phoneController.addListener(_refreshPreview);
    _alternatePhoneController.addListener(_refreshPreview);
    _addressController.addListener(_refreshPreview);
    _gstinController.addListener(_refreshPreview);
    _thankYouMessageController.addListener(_refreshPreview);
    _customFooterNoteController.addListener(_refreshPreview);
    _termsAndConditionsController.addListener(_refreshPreview);
    _upiIdController.addListener(_refreshPreview);
    _loadExistingShop();
  }

  @override
  void dispose() {
    _shopNameController
      ..removeListener(_refreshPreview)
      ..dispose();
    _taglineController
      ..removeListener(_refreshPreview)
      ..dispose();
    _phoneController
      ..removeListener(_refreshPreview)
      ..dispose();
    _alternatePhoneController
      ..removeListener(_refreshPreview)
      ..dispose();
    _addressController.dispose();
    _gstinController.dispose();
    _emailController.dispose();
    _upiIdController
      ..removeListener(_refreshPreview)
      ..dispose();
    _thankYouMessageController.dispose();
    _customFooterNoteController
      ..removeListener(_refreshPreview)
      ..dispose();
    _termsAndConditionsController
      ..removeListener(_refreshPreview)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadExistingShop() async {
    setState(() => _isLoading = true);
    try {
      final shopFuture = RestaurantApi.instance.fetchShop();
      final billTemplateFuture = () async {
        try {
          return await RestaurantApi.instance.fetchBillTemplate();
        } catch (_) {
          return null;
        }
      }();

      final results = await Future.wait([shopFuture, billTemplateFuture]);
      final shop = results[0] as ApiShopData;
      final billTemplate = results[1] as ApiBillTemplate?;

      if (!mounted) return;
      setState(() {
        if (shop.name.isNotEmpty) _shopNameController.text = shop.name;
        if (shop.tagline.isNotEmpty) _taglineController.text = shop.tagline;
        if (shop.phone != null) _phoneController.text = shop.phone!;
        if (shop.alternatePhone != null) {
          _alternatePhoneController.text = shop.alternatePhone!;
        }
        if (shop.address != null) _addressController.text = shop.address!;
        if (shop.email != null) _emailController.text = shop.email!;
        if (shop.gstin != null) _gstinController.text = shop.gstin!;
        if (shop.upiId != null) _upiIdController.text = shop.upiId!;
        if (shop.paymentModesConfig != null) {
          _selectedPaymentMode = shop.paymentModesConfig!;
        }

        if (billTemplate != null) {
          _billSettings['autoGenerateInvoice'] = true;
          _billSettings['showInvoiceNumber'] = billTemplate.showInvoiceNumber;
          _billSettings['showDateTime'] = billTemplate.showDateTime;
          _billSettings['showCustomerName'] = billTemplate.showCustomerDetails;
          _billSettings['showCustomerMobile'] =
              billTemplate.showCustomerDetails;
          _billSettings['showCashierName'] = true;
          _billSettings['showItemName'] = billTemplate.showItemName;
          _billSettings['showQuantity'] = billTemplate.showQuantity;
          _billSettings['showUnitPrice'] = billTemplate.showUnitPrice;
          _billSettings['showTotalPrice'] = billTemplate.showTotalPrice;
          _billSettings['showSubtotal'] = billTemplate.showSubtotal;
          _billSettings['showDiscount'] = billTemplate.showDiscount;
          _billSettings['showGstTax'] = billTemplate.showTax;
          _billSettings['showRoundOff'] = billTemplate.showRoundOff;
          _billSettings['showGrandTotal'] = billTemplate.showGrandTotal;
          _billSettings['showPaymentMethod'] = billTemplate.showPaymentMethod;
          _billSettings['showQrCode'] = true;
          _billSettings['showUpiId'] = billTemplate.showUpiId;

          _thankYouMessageController.text = billTemplate.footerMessage;
          _termsAndConditionsController.text = billTemplate.termsAndConditions;
        } else if (shop.billSettings != null && shop.billSettings!.isNotEmpty) {
          final s = shop.billSettings!;
          _billSettings.forEach((key, value) {
            if (s.containsKey(key)) {
              _billSettings[key] = s[key];
            }
          });
          if (s.containsKey('thankYouMessage')) {
            _thankYouMessageController.text = s['thankYouMessage'];
          }
          if (s.containsKey('customFooterNote')) {
            _customFooterNoteController.text = s['customFooterNote'];
          }
          if (s.containsKey('termsAndConditions')) {
            _termsAndConditionsController.text = s['termsAndConditions'];
          }
        }

        if (shop.logoUrl != null && shop.logoUrl!.isNotEmpty) {
          try {
            _logoBytes = base64Decode(shop.logoUrl!);
          } catch (_) {}
        }
        if (shop.qrUrl != null && shop.qrUrl!.isNotEmpty) {
          try {
            _qrBytes = base64Decode(shop.qrUrl!);
          } catch (_) {}
        }
      });
    } catch (_) {
      // Keep defaults if backend is unavailable
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
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.min(_panelWidth, constraints.maxWidth);

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: width,
                      child: _buildPanel(),
                    ),
                  ),
                );
              },
            ),
            if (_saving || _isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_primary),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(height: 16),
                          Text('Loading shop details...',
                              style: GoogleFonts.inter(color: _textSecondary)),
                        ],
                        if (_saving) ...[
                          const SizedBox(height: 16),
                          Text('Saving changes...',
                              style: GoogleFonts.inter(color: _textSecondary)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        _buildProgress(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildCard(
                'Branding & Visuals',
                icon: Icons.brush_rounded,
                [
                  _buildLogoUpload(),
                  const SizedBox(height: 16),
                  _buildQrUpload(),
                ],
              ),
              _buildCard(
                'Shop Information',
                icon: Icons.storefront_rounded,
                [
                  _buildTextField(label: 'Shop Name', controller: _shopNameController),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Tagline', controller: _taglineController),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Mobile Number', controller: _phoneController),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Alternate Mobile Number', controller: _alternatePhoneController),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Shop Address', controller: _addressController),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'GST Number', controller: _gstinController),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Email Address', controller: _emailController),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'UPI ID (For Payments)', controller: _upiIdController),
                ],
              ),
              _buildCard(
                'Payment Settings',
                icon: Icons.payments_rounded,
                [
                  _buildPaymentModes(),
                ],
              ),
              const SizedBox(height: 24),
              _buildSaveButton(),
              const SizedBox(height: 16),
              _buildFooterNote(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(String title, List<Widget> children, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _textPrimary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: _primary),
                const SizedBox(width: 8),
              ],
              Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: _textPrimary)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _handleBack,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: _textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shop Configuration',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  'Set up your business identity',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _softBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          _progressBar(active: true),
          const SizedBox(width: 6),
          _progressBar(active: true),
          const SizedBox(width: 6),
          _progressBar(),
        ],
      ),
    );
  }

  Widget _progressBar({bool active = false}) {
    return Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: active ? _primary : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ── Logo upload ────────────────────────────────────────────

  Widget _buildLogoUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Shop Logo'),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _saving ? null : _pickLogo,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _logoBytes != null ? Colors.transparent : _panelBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _logoBytes != null ? _primary : _border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _logoBytes != null
                      ? _buildLogoImage()
                      : const Icon(Icons.camera_alt_outlined, color: _textSecondary, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _logoBytes != null ? 'Logo Selected' : 'Upload your logo',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _logoBytes != null ? _primary : _textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This will appear on all your printed bills.',
                        style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.upload_file_rounded, color: _textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoImage() {
    return Image.memory(
      _logoBytes!,
      fit: BoxFit.cover,
      width: 72,
      height: 72,
    );
  }

  // ── QR Code upload ─────────────────────────────────────────

  Widget _buildQrUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Payment QR Code'),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _saving ? null : _pickQr,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _qrBytes != null ? Colors.transparent : _panelBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _qrBytes != null ? _primary : _border,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _qrBytes != null
                      ? Image.memory(_qrBytes!, fit: BoxFit.cover, width: 72, height: 72)
                      : const Icon(Icons.qr_code_2_rounded, color: _textSecondary, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _qrBytes != null ? 'QR Code Selected' : 'Upload UPI QR',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _qrBytes != null ? _primary : _textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customers can scan this to pay you directly.',
                        style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.upload_file_rounded, color: _textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Text fields ────────────────────────────────────────────

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: _textPrimary.withValues(alpha: 0.01),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ]
          ),
          child: TextField(
            controller: controller,
            enabled: !_saving,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ── Payment modes ──────────────────────────────────────────

  Widget _buildPaymentModes() {
    const modes = ['Cash', 'Online / UPI', 'Both'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Accepted Payment Modes'),
        const SizedBox(height: 8),
        Column(
          children: [
            for (final mode in modes) ...[
              _paymentModeRow(mode),
              if (mode != modes.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _paymentModeRow(String mode) {
    final selected = _selectedPaymentMode == mode;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _saving ? null : () => setState(() => _selectedPaymentMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _primary : _border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _primary : Colors.white,
                shape: BoxShape.circle,
                border:
                    selected ? null : Border.all(color: _border, width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mode,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected ? const Color(0xFF1E40AF) : _textSecondary,
                ),
              ),
            ),
            if (mode == 'Cash')
              const Icon(Icons.payments_outlined,
                  size: 18, color: Color(0xFF16A34A)),
            if (mode == 'Online / UPI')
              const Icon(Icons.phone_android_outlined,
                  size: 18, color: Color(0xFF2563EB)),
            if (mode == 'Both')
              const Icon(Icons.swap_horiz, size: 18, color: Color(0xFF7C3AED)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600, color: _primary),
        ),
      ),
    );
  }

  Widget _buildToggle(String title, String key) {
    return SwitchListTile(
      title: Text(title,
          style: GoogleFonts.inter(fontSize: 13, color: _textPrimary)),
      value: _billSettings[key] ?? true,
      onChanged: _saving
          ? null
          : (val) {
              setState(() => _billSettings[key] = val);
            },
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      activeThumbColor: _primary,
    );
  }

  Widget _buildBillSettingsPanel() {
    return ExpansionTile(
      title: Text('Bill Customization Settings',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _textPrimary)),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      tilePadding: EdgeInsets.zero,
      children: [
        _buildSectionTitle('Invoice Settings'),
        _buildToggle('Auto Generate Invoice Number', 'autoGenerateInvoice'),
        _buildToggle('Show Invoice Number', 'showInvoiceNumber'),
        _buildToggle('Show Date & Time', 'showDateTime'),
        _buildToggle('Show Cashier Name', 'showCashierName'),
        const Divider(),
        _buildSectionTitle('Customer Information'),
        _buildToggle('Show Customer Name', 'showCustomerName'),
        _buildToggle('Show Customer Mobile Number', 'showCustomerMobile'),
        const Divider(),
        _buildSectionTitle('Item Table Settings'),
        _buildToggle('Show Item Name', 'showItemName'),
        _buildToggle('Show Quantity', 'showQuantity'),
        _buildToggle('Show Unit Price', 'showUnitPrice'),
        _buildToggle('Show Total Price', 'showTotalPrice'),
        const Divider(),
        _buildSectionTitle('Amount Calculation Settings'),
        _buildToggle('Show Subtotal', 'showSubtotal'),
        _buildToggle('Show Discount', 'showDiscount'),
        _buildToggle('Show GST/Tax', 'showGstTax'),
        _buildToggle('Show Round Off', 'showRoundOff'),
        _buildToggle('Show Grand Total', 'showGrandTotal'),
        const Divider(),
        _buildSectionTitle('Payment Settings'),
        _buildToggle('Show Payment Method', 'showPaymentMethod'),
        _buildToggle('Show QR Code on Bill', 'showQrCode'),
        _buildToggle('Show UPI ID', 'showUpiId'),
        const Divider(),
        _buildSectionTitle('Footer Settings'),
        _buildTextField(
            label: 'Thank You Message', controller: _thankYouMessageController),
        const SizedBox(height: 10),
        _buildTextField(
            label: 'Custom Footer Note',
            controller: _customFooterNoteController),
        const SizedBox(height: 10),
        _buildTextField(
            label: 'Terms & Conditions',
            controller: _termsAndConditionsController),
      ],
    );
  }

  // ── Bill preview ───────────────────────────────────────────

  Widget _buildBillPreview() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _fieldLabel('Bill Slip Preview')),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Live Preview',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        BillReceiptWidget(
          template: ApiBillTemplate(
            id: 'preview',
            shopName: _receiptShopName,
            tagline: _receiptTagline,
            mobileNumber:
                _phoneController.text.isEmpty ? null : _phoneController.text,
            address: _addressController.text.isEmpty
                ? null
                : _addressController.text,
            email: _emailController.text.isEmpty ? null : _emailController.text,
            gstNumber:
                _gstinController.text.isEmpty ? null : _gstinController.text,
            showInvoiceNumber: _billSettings['showInvoiceNumber'] ?? true,
            showDateTime: _billSettings['showDateTime'] ?? true,
            showCustomerDetails: (_billSettings['showCustomerName'] ?? true) ||
                (_billSettings['showCustomerMobile'] ?? true),
            showDiscount: _billSettings['showDiscount'] ?? true,
            showTax: _billSettings['showGstTax'] ?? true,
            showItemName: _billSettings['showItemName'] ?? true,
            showQuantity: _billSettings['showQuantity'] ?? true,
            showUnitPrice: _billSettings['showUnitPrice'] ?? true,
            showTotalPrice: _billSettings['showTotalPrice'] ?? true,
            showSubtotal: _billSettings['showSubtotal'] ?? true,
            showRoundOff: _billSettings['showRoundOff'] ?? true,
            showGrandTotal: _billSettings['showGrandTotal'] ?? true,
            showPaymentMethod: _billSettings['showPaymentMethod'] ?? true,
            showUpiId: _billSettings['showUpiId'] ?? true,
            footerMessage: _thankYouMessageController.text,
            termsAndConditions: _termsAndConditionsController.text,
            themeColor: '#000000',
            templateDesign: 'standard',
          ),
          shopData: ApiShopData(
            id: 'preview',
            name: _receiptShopName,
            tagline: _receiptTagline,
            upiId: _upiIdController.text.isEmpty ? null : _upiIdController.text,
            billSettings: _billSettings,
          ),
          subtotal: 12.00,
          tax: 0.60,
          grandTotal: 12.60,
          logoBytesOverride: _logoBytes,
          qrBytesOverride: _qrBytes,
        ),
      ],
    );
  }

  // ── Save button ────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.indigo600, Color(0xFF4338CA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo600.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _saving ? null : _saveAndContinue,
        child: _saving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Save Shop Configuration',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                    ],
                  ),
                  Text('Proceed to Dashboard', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return Text.rich(
      TextSpan(
        text: 'You can change these settings anytime from ',
        children: [
          TextSpan(
            text: 'Account Settings',
            style: GoogleFonts.inter(color: _textPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
    );
  }

  Widget _fieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── Computed helpers ───────────────────────────────────────

  String get _receiptShopName {
    final value = _shopNameController.text.trim();
    return value.isEmpty ? 'SHOP NAME' : value.toUpperCase();
  }

  String get _receiptTagline {
    final value = _taglineController.text.trim();
    return value.isEmpty ? 'Your shop tagline' : value;
  }

  void _refreshPreview() => setState(() {});

  // ── Actions ────────────────────────────────────────────────

  Future<void> _pickLogo() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _logoBytes = bytes);
    } catch (e) {
      _showSnackBar('Could not access gallery: $e');
    }
  }

  Future<void> _pickQr() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _qrBytes = bytes);
    } catch (e) {
      _showSnackBar('Could not access gallery: $e');
    }
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _showSnackBar('Complete setup to continue');
  }

  Future<void> _saveAndContinue() async {
    if (_shopNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter shop name');
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(phone)) {
      _showSnackBar('Please enter a valid 10-digit mobile number');
      return;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnackBar('Please enter a valid email address');
      return;
    }
    
    final gstin = _gstinController.text.trim();
    if (gstin.isNotEmpty && !RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}$').hasMatch(gstin)) {
      _showSnackBar('Please enter a valid GSTIN');
      return;
    }

    setState(() => _saving = true);

    bool success = false;
    String? errorMessage;

    try {
      final logoBase64 = _logoBytes != null ? base64Encode(_logoBytes!) : null;
      final qrBase64 = _qrBytes != null ? base64Encode(_qrBytes!) : null;

      await RestaurantApi.instance.saveShop(
        ApiShopDraft(
          name: _shopNameController.text.trim(),
          tagline: _taglineController.text.trim(),
          phone: _phoneController.text.trim(),
          alternatePhone: _alternatePhoneController.text.trim(),
          address: _addressController.text.trim(),
          email: _emailController.text.trim(),
          gstin: _gstinController.text.trim(),
          upiId: _upiIdController.text.trim(),
          logoUrl: logoBase64,
          qrUrl: qrBase64,
          paymentModesConfig: _selectedPaymentMode,
          billSettings: {
            ..._billSettings,
            'thankYouMessage': _thankYouMessageController.text.trim(),
            'customFooterNote': _customFooterNoteController.text.trim(),
            'termsAndConditions': _termsAndConditionsController.text.trim(),
          },
        ),
      );

      await RestaurantApi.instance.saveBillTemplate(
        ApiBillTemplateDraft(
          logoUrl: logoBase64,
          shopName: _shopNameController.text.trim(),
          tagline: _taglineController.text.trim(),
          mobileNumber: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          gstNumber: _gstinController.text.trim(),
          qrCodeUrl: qrBase64,
          showInvoiceNumber: _billSettings['showInvoiceNumber'] ?? true,
          showDateTime: _billSettings['showDateTime'] ?? true,
          showCustomerDetails: _billSettings['showCustomerName'] ?? true,
          showDiscount: _billSettings['showDiscount'] ?? true,
          showTax: _billSettings['showGstTax'] ?? true,
          showItemName: _billSettings['showItemName'] ?? true,
          showQuantity: _billSettings['showQuantity'] ?? true,
          showUnitPrice: _billSettings['showUnitPrice'] ?? true,
          showTotalPrice: _billSettings['showTotalPrice'] ?? true,
          showSubtotal: _billSettings['showSubtotal'] ?? true,
          showRoundOff: _billSettings['showRoundOff'] ?? true,
          showGrandTotal: _billSettings['showGrandTotal'] ?? true,
          showPaymentMethod: _billSettings['showPaymentMethod'] ?? true,
          showUpiId: _billSettings['showUpiId'] ?? true,
          footerMessage: _thankYouMessageController.text.trim(),
          termsAndConditions: _termsAndConditionsController.text.trim(),
        ),
      );
      success = true;
    } on TimeoutException {
      errorMessage = 'Server is taking too long. Is the backend running?';
    } catch (e) {
      errorMessage =
          'Save failed: ${e.toString().replaceAll('Exception: ', '')}';
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
                errorMessage ?? 'Saved in Offline Mode (Backend Unreachable)'),
            backgroundColor: const Color(0xFFF59E0B), // Orange warning color
            duration: const Duration(seconds: 4),
          ),
        );
      
      // Proceed offline instead of blocking the user completely.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isSetupComplete', true);
      _showSuccessAnimationAndRedirect();
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Shop and Bill settings saved to Backend!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isSetupComplete', true);

    _showSuccessAnimationAndRedirect();
  }

  void _showSuccessAnimationAndRedirect() {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Material(
              color: Colors.black.withValues(alpha: 0.6 * value),
              child: Center(
                child: Transform.scale(
                  scale: Curves.easeOutBack.transform(value),
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 40),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bill Template Saved\nSuccessfully',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Navigate instantly without delay
    overlayEntry.remove();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
