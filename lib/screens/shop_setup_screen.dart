import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/restaurant_api.dart';
import '../utils/local_storage_helper.dart';
import 'main_screen.dart';
import 'dart:math' as math;
import 'dart:typed_data';

class ShopSetupScreen extends StatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  static const Color _primary = Color(0xFF111111);
  static const Color _textSecondary = Color(0xFF71717A);
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

  int _currentStep = 1;
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

        // Load images from local storage directly
        LocalImageStorage.loadImageBytes('shop_logo.png').then((bytes) {
          if (mounted && bytes != null) {
            setState(() {
              _logoBytes = bytes;
            });
          }
        });
        
        LocalImageStorage.loadImageBytes('shop_qr.png').then((bytes) {
          if (mounted && bytes != null) {
            setState(() {
              _qrBytes = bytes;
            });
          }
        });
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
    Widget stepContent;
    switch (_currentStep) {
      case 1:
        stepContent = _buildCard(
          'Branding & Visuals',
          icon: Icons.palette_outlined,
          [
            _buildLogoUpload(),
            const SizedBox(height: 16),
            _buildQrUpload(),
          ],
        );
        break;
      case 2:
        stepContent = _buildCard(
          'CORE DETAILS',
          icon: Icons.storefront_outlined,
          [
            _buildTextField(label: 'SHOP NAME', controller: _shopNameController, placeholder: 'e.g. Yamunaji Food'),
            const SizedBox(height: 14),
            _buildTextField(label: 'TAGLINE', controller: _taglineController, placeholder: 'Brief shop motto or slogan'),
            const SizedBox(height: 14),
            _buildTextField(label: 'MOBILE NUMBER', controller: _phoneController, placeholder: '10-digit primary contact', keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            _buildTextField(label: 'ALTERNATE MOBILE NUMBER', controller: _alternatePhoneController, placeholder: 'Optional contact number', isOptional: true, keyboardType: TextInputType.phone),
          ],
        );
        break;
      case 3:
        stepContent = _buildCard(
          'REGISTRATION & CONTACT',
          icon: Icons.assignment_outlined,
          [
            _buildTextField(
              label: 'SHOP ADDRESS',
              controller: _addressController,
              placeholder: 'Shop No., Landmark, City, Pincode',
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              label: 'GST NUMBER',
              controller: _gstinController,
              placeholder: '22AAAAA0000A1Z5 (Optional)',
              isOptional: true,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              label: 'EMAIL ADDRESS',
              controller: _emailController,
              placeholder: 'owner@storename.com',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              label: 'UPI ID (FOR PAYMENTS)',
              controller: _upiIdController,
              placeholder: 'storename@okhdfcbank',
            ),
          ],
        );
        break;
      case 4:
      default:
        stepContent = _buildCard(
          'Payment Preferences',
          subtitle: 'Choose checkout options allowed in your POS',
          icon: Icons.payment_rounded,
          [
            _buildPaymentModes(),
          ],
        );
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        _buildProgress(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              stepContent,
              const SizedBox(height: 16),
              _buildBottomNav(),
              const SizedBox(height: 14),
              _buildFooterNote(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(String title, List<Widget> children, {IconData? icon, String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Icon(icon, size: 15, color: const Color(0xFF111111)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF111111),
                        letterSpacing: title == title.toUpperCase() ? 0.8 : -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF71717A)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF4F4F5)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _handleBack,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF111111)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shop Configuration',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111111),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Step $_currentStep of 4',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF71717A),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _progressBar(active: _currentStep >= 1),
          const SizedBox(width: 6),
          _progressBar(active: _currentStep >= 2),
          const SizedBox(width: 6),
          _progressBar(active: _currentStep >= 3),
          const SizedBox(width: 6),
          _progressBar(active: _currentStep >= 4),
        ],
      ),
    );
  }

  Widget _progressBar({bool active = false}) {
    return Expanded(
      child: Container(
        height: 3.5,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF111111) : const Color(0xFFE5E5E5),
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
        _fieldLabel('SHOP LOGO'),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _saving ? null : _pickLogo,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: _logoBytes != null ? const Color(0xFF111111) : const Color(0xFFD4D4D8),
              borderRadius: 8,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF9F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _logoBytes != null
                        ? Image.memory(_logoBytes!, fit: BoxFit.cover, width: 50, height: 50)
                        : const Icon(Icons.camera_alt_outlined, color: Color(0xFF52525B), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _logoBytes != null ? 'Logo Selected' : 'Upload your logo',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'This will appear on all your printed bills.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF71717A)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: const Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFF71717A)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── QR Code upload ─────────────────────────────────────────

  Widget _buildQrUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('PAYMENT QR CODE'),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _saving ? null : _pickQr,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: _qrBytes != null ? const Color(0xFF111111) : const Color(0xFFD4D4D8),
              borderRadius: 8,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF9F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _qrBytes != null
                        ? Image.memory(_qrBytes!, fit: BoxFit.cover, width: 50, height: 50)
                        : const Icon(Icons.qr_code_2_rounded, color: Color(0xFF52525B), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _qrBytes != null ? 'QR Code Selected' : 'Upload UPI QR',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Customers can scan this to pay you directly.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF71717A)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: const Icon(Icons.file_upload_outlined, size: 18, color: Color(0xFF71717A)),
                  ),
                ],
              ),
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
    String? placeholder,
    bool isOptional = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _fieldLabel(label),
            if (isOptional)
              Text(
                'Optional',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFA1A1AA),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: maxLines > 1 ? (42.0 + (maxLines - 1) * 20.0) : 42.0,
          decoration: BoxDecoration(
            color: const Color(0xFFFBF9F8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          child: TextField(
            controller: controller,
            enabled: !_saving,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF111111),
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFA1A1AA),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
        _fieldLabel('ACCEPTED PAYMENT MODES'),
        const SizedBox(height: 12),
        Column(
          children: [
            for (final mode in modes) ...[
              _paymentModeRow(mode),
              if (mode != modes.last) const SizedBox(height: 10),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFF4F4F5))),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: Color(0xFF71717A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Customers can pay either via paper money or digital scanners.',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF71717A)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentModeRow(String mode) {
    final selected = _selectedPaymentMode == mode;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _saving ? null : () => setState(() => _selectedPaymentMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF111111) : const Color(0xFFE5E5E5),
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF111111) : Colors.white,
                shape: BoxShape.circle,
                border: selected ? null : Border.all(color: const Color(0xFFD4D4D8), width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mode,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: const Color(0xFF111111),
                ),
              ),
            ),
            if (mode == 'Cash')
              const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF71717A)),
            if (mode == 'Online / UPI')
              const Icon(Icons.smartphone_rounded, size: 18, color: Color(0xFF71717A)),
            if (mode == 'Both')
              Icon(Icons.swap_horiz, size: 18, color: selected ? const Color(0xFF111111) : const Color(0xFF71717A)),
          ],
        ),
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────

  Widget _buildBottomNav() {
    if (_currentStep == 4) {
      return _buildSaveButton();
    }

    if (_currentStep == 1) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            setState(() => _currentStep++);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Next Step',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFD4D4D8)),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => setState(() => _currentStep--),
            child: Text(
              'Back',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111111),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                setState(() => _currentStep++);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Next Step',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF111111),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _saving ? null : _saveAndContinue,
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Save Shop Configuration',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Proceed to Dashboard',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400, color: const Color(0xFFA1A1AA)),
                  ),
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
            style: GoogleFonts.inter(color: const Color(0xFF111111), fontWeight: FontWeight.w700),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF71717A)),
    );
  }

  Widget _fieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF71717A),
          letterSpacing: 0.8,
        ),
      ),
    );
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
    if (_currentStep > 1) {
      setState(() => _currentStep--);
      return;
    }
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

      if (_logoBytes != null) {
        await LocalImageStorage.saveImage('shop_logo.png', _logoBytes!);
      }
      if (_qrBytes != null) {
        await LocalImageStorage.saveImage('shop_qr.png', _qrBytes!);
      }

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

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  _DashedBorderPainter({
    this.color = const Color(0xFFD4D4D8),
    this.borderRadius = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.0;
    const dash = 5.0;
    const gap = 3.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dash > metric.length) ? metric.length - distance : dash;
        canvas.drawPath(
          metric.extractPath(distance, distance + len),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

