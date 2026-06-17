import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/restaurant_api.dart';
import '../widgets/bill_receipt_widget.dart';

import '../services/printer_service.dart';
import 'kitchen_slip_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'success_screen.dart';

class PrintPreviewScreen extends StatefulWidget {
  const PrintPreviewScreen({
    super.key,
    this.orderId = '#2904-X',
    this.tokenNumber = '#T-001',
    this.billNumber,
    this.paymentMode = 'Cash',
    this.logoBase64,
    this.qrBase64,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.grandTotal,
    this.onSaveBill,
  });

  final String orderId;
  final String tokenNumber;
  final String? billNumber;
  final String paymentMode;
  final Future<ApiToken?> Function()? onSaveBill;

  /// Pre-loaded base64 logo (optional – if null we fetch from API)
  final String? logoBase64;

  /// Pre-loaded base64 QR (optional – if null we fetch from API)
  final String? qrBase64;
  final List<ApiTokenItemDraft> items;
  final double subtotal;
  final double tax;
  final double grandTotal;

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  static const Color _panelBackground = Color(0xFFF5F6FA);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textPrimary = Color(0xFF1F2937);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _muted = Color(0xFFAAAAAA);
  static const Color _softBorder = Color(0xFFEEEEEE);
  static const double _panelWidth = 360;

  String _shopName = 'GOURMET EXPRESS';
  Uint8List? _logoBytes;
  Uint8List? _qrBytes;
  late String _actualTokenNumber;
  ApiBillTemplate? _billTemplate;
  ApiShopData? _shopData;
  bool _isLoading = true;
  bool _isPrinting = false;
  ApiToken? _savedToken;

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  void initState() {
    super.initState();
    _actualTokenNumber = widget.tokenNumber;
    _initImages();
  }

  Future<void> _initImages() async {
    // Use pre-loaded values if provided
    if (widget.logoBase64 != null && widget.logoBase64!.isNotEmpty) {
      try {
        _logoBytes = base64Decode(widget.logoBase64!);
      } catch (_) {}
    }
    if (widget.qrBase64 != null && widget.qrBase64!.isNotEmpty) {
      try {
        _qrBytes = base64Decode(widget.qrBase64!);
      } catch (_) {}
    }

    ApiShopData? shop;
    ApiBillTemplate? template;

    try {
      shop = await RestaurantApi.instance.fetchShop();
    } catch (_) {
      // Offline or error
    }

    try {
      template = await RestaurantApi.instance.fetchBillTemplate();
    } catch (_) {
      // Offline or error
    }

    if (!mounted) return;

    // Fallback if shop is null
    final finalShop = shop ??
        const ApiShopData(
          id: 'offline',
          name: 'Offline Shop',
          tagline: '',
          address: 'Offline Address',
          phone: '',
        );

    // Fallback if template is null
    final finalTemplate = template ??
        ApiBillTemplate(
          id: 'fallback',
          shopName: finalShop.name.isNotEmpty ? finalShop.name : 'MY SHOP',
          address: finalShop.address,
          mobileNumber: finalShop.phone,
          gstNumber: '',
          footerMessage: 'Thank you for visiting!',
        );

    Uint8List? logo = _logoBytes;
    Uint8List? qr = _qrBytes;

    if (logo == null && finalShop.logoUrl != null && finalShop.logoUrl!.isNotEmpty) {
      try {
        logo = base64Decode(finalShop.logoUrl!);
      } catch (_) {}
    }
    if (qr == null && finalShop.qrUrl != null && finalShop.qrUrl!.isNotEmpty) {
      try {
        qr = base64Decode(finalShop.qrUrl!);
      } catch (_) {}
    }

    setState(() {
      _shopName = finalTemplate.shopName?.isNotEmpty == true
          ? finalTemplate.shopName!
          : finalShop.name.toUpperCase();
      _logoBytes = logo;
      _qrBytes = qr;
      _billTemplate = finalTemplate;
      _shopData = finalShop;
      _isLoading = false;
    });
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
                    child: SizedBox(width: width, child: _buildPanel()),
                  ),
                );
              },
            ),
            if (_isPrinting || _isLoading)
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _panelBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildReceipt(),
                    if (_isLoading)
                      Container(
                        width: double.infinity,
                        height: 300,
                        color: Colors.white.withValues(alpha: 0.7),
                        child: const Center(
                          child: CircularProgressIndicator(color: _primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _connectionBanner(),
                const SizedBox(height: 12),
                _primaryPrintActions(),
                const SizedBox(height: 8),
                _secondaryActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _softBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.arrow_back,
                      size: 19,
                      color: Color(0xFF555555),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bill Preview',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Order ID: ${widget.orderId}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: () => _showSnackBar('Share options opened'),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share, size: 16, color: _primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceipt() {
    if (_billTemplate == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return BillReceiptWidget(
      template: _billTemplate!,
      shopData: _shopData,
      tokenNumber: _actualTokenNumber,
      billNumber: widget.billNumber,
      date: _formatDate(DateTime.now()),
      time: _formatTime(DateTime.now()),
      items: widget.items,
      subtotal: widget.subtotal,
      tax: widget.tax,
      grandTotal: widget.grandTotal,
      paymentMode: widget.paymentMode,
      logoBytesOverride: _logoBytes,
      qrBytesOverride: _qrBytes,
    );
  }

  Widget _connectionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 0.5),
      ),
      child: const Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: Color(0xFF16A34A)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Printer Connected: BT-P58-PRO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryPrintActions() {
    return Row(
      children: [
        Expanded(
          child: _stackedButton(
            label: 'Customer Slip',
            subtitle: 'Print Bill',
            icon: Icons.receipt_long_outlined,
            background: _primary,
            subtitleColor: const Color(0xFF93C5FD),
            isLoading: _isPrinting,
            onTap: _saveAndPrint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _stackedButton(
            label: 'Kitchen Slip',
            subtitle: 'Send to KOT',
            icon: Icons.restaurant_menu,
            background: const Color(0xFF111111),
            subtitleColor: _muted,
            isLoading: _isPrinting,
            onTap: _openKitchenSlip,
          ),
        ),
      ],
    );
  }

  Widget _stackedButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color background,
    required Color subtitleColor,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 16, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: subtitleColor),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _secondaryActions() {
    return Row(
      children: [
        Expanded(
          child: _outlineAction(
            'Reprint',
            Icons.refresh,
            _textSecondary,
            _saveAndPrint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _outlineAction(
            'Share WA',
            Icons.chat_outlined,
            const Color(0xFF16A34A),
            _shareWhatsApp,
          ),
        ),
      ],
    );
  }

  Future<void> _shareWhatsApp() async {
    final text =
        'Hello,\nHere is your Bill $_actualTokenNumber for Rs. ${widget.grandTotal}.\nThank you for visiting $_shopName!';
    final url = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showSnackBar('WhatsApp is not installed');
      }
    } catch (e) {
      _showSnackBar('Could not launch WhatsApp');
    }
  }

  Widget _outlineAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _panelBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _softBorder, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  void _saveAndPrint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    
    final isConnected = await PrinterService.instance.bluetooth.isConnected;
    if (isConnected != true) {
      if (mounted) setState(() => _isPrinting = false);
      _showSnackBar('First off all connect your printer');
      return;
    }
    
    if (widget.onSaveBill != null && _savedToken == null) {
      try {
        _savedToken = await widget.onSaveBill!();
        if (_savedToken == null) {
          if (mounted) setState(() => _isPrinting = false);
          _showSnackBar('Unable to save bill. Please try again.');
          return;
        }
      } catch (e) {
        if (mounted) setState(() => _isPrinting = false);
        _showSnackBar('Error generating bill: $e');
        return;
      }
    }
    
    // Use savedToken or mock a token for printing if not saving
    final tokenToPrint = _savedToken ?? ApiToken(
      id: '',
      tokenNumber: _actualTokenNumber,
      billNumber: widget.billNumber ?? '',
      status: 'PENDING',
      customerName: '',
      customerPhone: '',
      grandTotal: widget.grandTotal,
      paymentMode: widget.paymentMode,
      createdAt: DateTime.now().toIso8601String(),
      items: widget.items
          .map((i) => ApiTokenItem(
              id: i.id ?? '',
              name: i.name,
              code: i.code,
              rate: i.rate,
              quantity: i.quantity,
              subtotal: i.rate * i.quantity))
          .toList(),
      orderType: 'dine_in',
    );

    // Hardware Printing Call
    try {
      if (_shopData != null && _billTemplate != null) {
        await PrinterService.instance
            .printReceipt(tokenToPrint, _shopData!, _billTemplate!);
        _showSnackBar('Receipt sent to thermal printer');
      }
    } catch (e) {
      debugPrint('Printer error: $e');
      _showSnackBar('Printer Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }

    _showPrintSuccessAnimationAndPrint();
  }

  void _showPrintSuccessAnimationAndPrint() {
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
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.print,
                                color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Bill Generated\nSuccessfully',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
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

    // Removed artificial delay
    if (!mounted) return;
    overlayEntry.remove();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (context) => const SuccessScreen(isPrinted: true)),
    );
  }

  Future<void> _openKitchenSlip() async {
    if (widget.onSaveBill != null && _savedToken == null) {
      try {
        _savedToken = await widget.onSaveBill!();
        if (_savedToken == null) {
          _showSnackBar('Unable to save bill. Please try again.');
          return;
        }
      } catch (e) {
        _showSnackBar('Error generating bill: $e');
        return;
      }
    }

    // Use savedToken or mock a token for printing if not saving
    final tokenToUse = _savedToken ?? ApiToken(
      id: '',
      tokenNumber: _actualTokenNumber,
      billNumber: widget.billNumber ?? '',
      status: 'PENDING',
      customerName: '',
      customerPhone: '',
      grandTotal: widget.grandTotal,
      paymentMode: widget.paymentMode,
      createdAt: DateTime.now().toIso8601String(),
      items: widget.items
          .map((i) => ApiTokenItem(
              id: i.id ?? '',
              name: i.name,
              code: i.code,
              rate: i.rate,
              quantity: i.quantity,
              subtotal: i.rate * i.quantity))
          .toList(),
      orderType: 'dine_in',
    );

    // Hardware Printing Call
    try {
      final isConnected = await PrinterService.instance.bluetooth.isConnected;
      if (isConnected != true) {
        if (mounted) setState(() => _isPrinting = false);
        _showSnackBar('First off all connect your printer');
        return;
      }

      await PrinterService.instance.printKitchenSlip(tokenToUse);
      _showSnackBar('KOT sent to thermal printer');
    } catch (e) {
      _showSnackBar('Printer error: $e');
    }

    if (mounted) {
      setState(() => _isPrinting = false);
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (context) => KitchenSlipScreen(token: tokenToUse)),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
