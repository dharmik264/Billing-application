import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../services/pdf_receipt_service.dart';
import '../services/printer_service.dart';
import '../services/restaurant_api.dart';
import '../utils/bill_settings_helper.dart';
import '../widgets/bill_receipt_widget.dart';
import '../widgets/bill_a4_receipt_widget.dart';
import '../widgets/app_bottom_navbar.dart';

import 'main_screen.dart';
import 'printer_setup_screen.dart';

class PrintPreviewScreen extends StatefulWidget {
  const PrintPreviewScreen({
    super.key,
    this.orderId = '#2904-X',
    this.tokenNumber = '#T-001',
    this.billNumber,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.customerGstNumber,
    this.paymentMode = 'Cash',
    this.logoBase64,
    this.qrBase64,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.grandTotal,
    this.onSaveBill,
    this.fromTokenGeneration = false,
    this.billFormat,
  });

  final String orderId;
  final String tokenNumber;
  final String? billNumber;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? customerGstNumber;
  final String paymentMode;
  final Future<ApiToken?> Function()? onSaveBill;
  final bool fromTokenGeneration;
  final String? billFormat;

  final String? logoBase64;
  final String? qrBase64;
  final List<ApiTokenItemDraft> items;
  final double subtotal;
  final double tax;
  final double grandTotal;

  @override
  State<PrintPreviewScreen> createState() => _PrintPreviewScreenState();
}

class _PrintPreviewScreenState extends State<PrintPreviewScreen> {
  static const Color _bgCanvas = Color(0xFFF0EEEB);
  static const Color _brandBg = Color(0xFFFBF9F8);
  static const Color _brandPrimary = Color(0xFF111111);
  static const Color _brandSecondary = Color(0xFF666666);
  static const Color _brandMuted = Color(0xFF8C8C8C);
  static const Color _brandBorder = Color(0xFFE5E5E5);

  Uint8List? _logoBytes;
  Uint8List? _qrBytes;
  late String _actualTokenNumber;
  ApiBillTemplate? _billTemplate;
  ApiShopData? _shopData;
  bool _isLoading = true;
  bool _isPrinting = false;
  bool _isCapturingForPrint = false;
  ApiToken? _savedToken;
  String _billFormat = 'Bill Slip';

  bool get _isA4 => _billFormat.toLowerCase().contains('a4');

  final bool _printCustomerSlip = true;
  final bool _printKitchenSlip = true;
  final GlobalKey _receiptKey = GlobalKey();

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  void initState() {
    super.initState();
    _actualTokenNumber = widget.tokenNumber;
    if (widget.billFormat != null && widget.billFormat!.isNotEmpty) {
      _billFormat = widget.billFormat!;
    }
    _initImages();
    PrinterService.instance.attemptAutoConnect();
  }

  Future<void> _initImages() async {
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
    } catch (_) {}

    try {
      template = await RestaurantApi.instance.fetchBillTemplate();
    } catch (_) {}

    if (!mounted) return;

    final finalShop = shop ??
        const ApiShopData(
          id: 'offline',
          name: 'YAMUNAJI FOOD',
          tagline: '',
          address: 'Offline Address',
          phone: '+91 99887 79988',
        );

    final finalTemplate = template ??
        ApiBillTemplate(
          id: 'fallback',
          shopName: finalShop.name.isNotEmpty ? finalShop.name : 'YAMUNAJI FOOD',
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

    final billFormat = widget.billFormat ?? await BillSettingsHelper.getBillFormat();

    setState(() {
      _logoBytes = logo;
      _qrBytes = qr;
      _billTemplate = finalTemplate;
      _shopData = finalShop;
      _billFormat = billFormat;
      _isLoading = false;
    });
  }

  void _handleBackNavigation() {
    if (widget.fromTokenGeneration) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen(initialIndex: 0)),
        (route) => false,
      );
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainScreen(initialIndex: 1)),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: _bgCanvas,
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: _isA4 ? 650 : 420),
              color: _brandBg,
              child: Column(
                children: [
                  // Sticky Top Bar
                  _buildTopBar(),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Format Selector Tabs (Bill Slip vs Bill A4)
                          _buildFormatSelector(),
                          const SizedBox(height: 12),

                          // Hardware / Document Status Banner
                          _buildHardwareStatus(),
                          const SizedBox(height: 16),

                          // Main Invoice Receipt Sheet (Slip or A4)
                          _buildInvoiceCard(),
                          const SizedBox(height: 16),

                          // Action Buttons Grid (Print / Share)
                          _buildActionButtons(),
                          const SizedBox(height: 8),

                          // Helper Text
                          Text(
                            _isA4
                                ? 'A4 Invoice format · Ready for standard printer or sharing'
                                : 'Thermal Slip format · Order completed',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: _brandMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Navigation Bar (Matching Home page navbar component)
                  AppBottomNavbar(
                    currentIndex: 1, // Token active tab
                    onTap: (index) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => MainScreen(initialIndex: index)),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _brandBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _handleBackNavigation,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: _brandPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bill Preview',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _brandPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'Order ${widget.orderId}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _brandMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _brandBorder),
            ),
            child: Text(
              _isA4 ? 'A4 INVOICE' : 'TAX INVOICE SLIP',
              style: GoogleFonts.spaceMono(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _brandSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _brandBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _billFormat = 'Bill Slip');
                BillSettingsHelper.setBillFormat('Bill Slip');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isA4 ? _brandPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_outlined,
                        size: 15,
                        color: !_isA4 ? Colors.white : _brandSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Bill Slip (POS)',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: !_isA4 ? Colors.white : _brandSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _billFormat = 'Bill A4');
                BillSettingsHelper.setBillFormat('Bill A4');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isA4 ? _brandPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 15,
                        color: _isA4 ? Colors.white : _brandSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Bill A4',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isA4 ? Colors.white : _brandSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareStatus() {
    if (_isA4) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _brandBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Format: A4 Page',
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _brandPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Standard Print / PDF',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _brandSecondary,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                setState(() => _billFormat = 'Bill Slip');
                BillSettingsHelper.setBillFormat('Bill Slip');
              },
              child: Text(
                'Switch to Slip',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2563EB),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<bool>(
      future: PrinterService.instance.isConnected,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? false;
        const printerName = 'BT-P58-PRO';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _brandBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConnected ? const Color(0xFF16A34A) : Colors.amber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isConnected ? const Color(0xFF16A34A) : Colors.amber).withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    printerName,
                    style: GoogleFonts.spaceMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? 'Connected' : 'Ready',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _brandSecondary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PrinterSetupScreen()),
                  );
                },
                child: Text(
                  'Settings',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _brandPrimary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoiceCard() {
    if (_isLoading || _billTemplate == null) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _brandBorder),
        ),
        child: const CircularProgressIndicator(color: _brandPrimary),
      );
    }

    final isA4 = _isA4;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _brandBorder),
        boxShadow: isA4
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: RepaintBoundary(
        key: _receiptKey,
        child: isA4
            ? BillA4ReceiptWidget(
                template: _billTemplate!,
                shopData: _shopData,
                tokenNumber: _actualTokenNumber,
                billNumber: widget.billNumber,
                customerName: widget.customerName,
                customerPhone: widget.customerPhone,
                customerAddress: widget.customerAddress,
                customerGstNumber: widget.customerGstNumber,
                date: _formatDate(DateTime.now()),
                time: _formatTime(DateTime.now()),
                items: widget.items,
                subtotal: widget.subtotal,
                tax: widget.tax,
                grandTotal: widget.grandTotal,
                paymentMode: widget.paymentMode,
                logoBytesOverride: _logoBytes,
                qrBytesOverride: _qrBytes,
              )
            : BillReceiptWidget(
                template: _billTemplate!,
                shopData: _shopData,
                tokenNumber: _actualTokenNumber,
                billNumber: widget.billNumber,
                customerName: widget.customerName,
                customerPhone: widget.customerPhone,
                customerAddress: widget.customerAddress,
                customerGstNumber: widget.customerGstNumber,
                date: _formatDate(DateTime.now()),
                time: _formatTime(DateTime.now()),
                items: widget.items,
                subtotal: widget.subtotal,
                tax: widget.tax,
                grandTotal: widget.grandTotal,
                paymentMode: widget.paymentMode,
                logoBytesOverride: _logoBytes,
                qrBytesOverride: _qrBytes,
                isForPrint: _isCapturingForPrint,
                is80mm: PrinterService.instance.is80mm,
              ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isA4 = _isA4;

    return Row(
      children: [
        // Solid Black Primary CTA: Print Bill
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isPrinting ? null : _executePrint,
              child: _isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.print_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          isA4 ? 'Print A4 Bill' : 'Print Bill',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Outlined Secondary CTA: Share Bill
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _brandPrimary,
                side: const BorderSide(color: _brandBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isPrinting ? null : _shareBill,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isA4 ? Icons.picture_as_pdf_outlined : Icons.share_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isA4 ? 'Share A4 PDF' : 'Share Bill',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  ApiToken _generatePreviewToken() {
    return ApiToken(
      id: widget.orderId,
      shopId: _shopData?.id ?? '',
      tokenNumber: _actualTokenNumber,
      billNumber: widget.billNumber ?? '',
      orderType: 'Walk-in',
      paymentMode: widget.paymentMode,
      status: 'completed',
      subtotal: widget.subtotal,
      tax: widget.tax,
      discount: 0.0,
      grandTotal: widget.grandTotal,
      customerName: widget.customerName ?? '',
      customerPhone: widget.customerPhone ?? '',
      customerAddress: widget.customerAddress ?? '',
      customerGstNumber: widget.customerGstNumber ?? '',
      items: widget.items.map((e) => ApiTokenItem(
        id: e.id ?? '',
        name: e.name,
        code: e.code,
        rate: e.rate,
        quantity: e.quantity,
        subtotal: e.rate * e.quantity,
      )).toList(),
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> _shareBill() async {
    setState(() => _isPrinting = true);
    try {
      final token = ApiToken(
        id: widget.orderId,
        shopId: _shopData?.id ?? '',
        tokenNumber: _actualTokenNumber,
        billNumber: widget.billNumber ?? '',
        orderType: 'Walk-in',
        paymentMode: widget.paymentMode,
        status: 'completed',
        subtotal: widget.subtotal,
        tax: widget.tax,
        discount: 0.0,
        grandTotal: widget.grandTotal,
        customerName: widget.customerName ?? '',
        customerPhone: widget.customerPhone ?? '',
        customerAddress: widget.customerAddress ?? '',
        customerGstNumber: widget.customerGstNumber ?? '',
        items: widget.items.map((e) => ApiTokenItem(
          id: e.id ?? '',
          name: e.name,
          code: e.code,
          rate: e.rate,
          quantity: e.quantity,
          subtotal: e.rate * e.quantity,
        )).toList(),
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      final isA4 = _isA4;
      final pdfBytes = await PdfReceiptService.generateReceipt(token, isThermal: !isA4);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Bill_${widget.billNumber ?? widget.tokenNumber}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share bill: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _executePrint() async {
    if (_isPrinting) return;
    if (!_printCustomerSlip && !_printKitchenSlip) {
      _showSnackBar('Please select at least one slip to print');
      return;
    }

    setState(() => _isPrinting = true);

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

    final tokenToPrint = _savedToken ?? _generatePreviewToken();

    if (_isA4) {
      try {
        await PdfReceiptService.printReceipt(tokenToPrint, isThermal: false);
      } catch (e) {
        debugPrint('Print error: $e');
        _showSnackBar('Unable to print A4 bill.');
      } finally {
        if (mounted) {
          setState(() {
            _isPrinting = false;
            _isCapturingForPrint = false;
          });
        }
      }
      return;
    }

    if (kIsWeb) {
      final pngBytes = await _captureReceiptPng();
      if (pngBytes != null) {
        await PrinterService.instance.printWebReceipt(pngBytes, is80mm: PrinterService.instance.is80mm);
      }
      if (mounted) setState(() => _isPrinting = false);
      return;
    }

    bool? isConnected = false;
    try {
      isConnected = await PrinterService.instance.bluetooth.isConnected
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Bluetooth check error: $e');
    }

    if (isConnected != true) {
      if (mounted) setState(() => _isPrinting = false);
      _showSnackBar('Printer is not connected.');
      return;
    }

    try {
      if (_printCustomerSlip) {
        if (_shopData != null && _billTemplate != null) {
          await PrinterService.instance.printReceipt(tokenToPrint, _shopData!, _billTemplate!);
        } else {
          final pngBytes = await _captureReceiptPng();
          if (pngBytes != null) {
            await PrinterService.instance.printReceiptImage(pngBytes);
          }
        }
      }

      if (_printKitchenSlip) {
        await PrinterService.instance.printKitchenSlip(tokenToPrint);
      }

      _showSnackBar('Slips sent to thermal printer');
    } catch (e) {
      debugPrint('Printer error: $e');
      _showSnackBar('Unable to print. Please check printer connection.');
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
          _isCapturingForPrint = false;
        });
      }
    }
  }

  Future<Uint8List?> _captureReceiptPng() async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Capture receipt error: $e');
      return null;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
