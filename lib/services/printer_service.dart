import 'dart:typed_data';
import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show debugPrint;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import 'restaurant_api.dart';

class PrinterService {
  PrinterService._privateConstructor();
  static final PrinterService instance = PrinterService._privateConstructor();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  String? _printerIp;
  bool _isNetworkPrinter = false;
  PaperSize _paperSize = PaperSize.mm58;
  bool get is80mm => _paperSize == PaperSize.mm80;

  bool _lastConnectionStatus = false;
  DateTime _lastConnectionCheck = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> initPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final sizeStr = prefs.getString('paper_size') ?? '58 mm';
    _paperSize = sizeStr == '80 mm' ? PaperSize.mm80 : PaperSize.mm58;

    _printerIp = prefs.getString('printer_ip');
    _isNetworkPrinter = prefs.getBool('is_network_printer') ?? false;
  }

  Future<List<BluetoothDevice>> getDevices() async {
    try {
      return await bluetooth.getBondedDevices();
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      await bluetooth.connect(device);
      _isNetworkPrinter = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_mac', device.address ?? '');
      await prefs.setBool('is_network_printer', false);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await bluetooth.disconnect();
      _isNetworkPrinter = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('printer_mac');
      await prefs.remove('printer_ip');
      await prefs.remove('is_network_printer');
      // ignore: empty_catches
    } catch (e) {}
  }

  Future<bool> connectNetwork(String ip) async {
    try {
      final socket =
          await Socket.connect(ip, 9100, timeout: const Duration(seconds: 3));
      socket.destroy();

      _printerIp = ip;
      _isNetworkPrinter = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_ip', ip);
      await prefs.setBool('is_network_printer', true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get isConnected async {
    if (kIsWeb) return false;

    final now = DateTime.now();
    if (now.difference(_lastConnectionCheck).inSeconds < 5) {
      return _lastConnectionStatus;
    }

    if (_isNetworkPrinter && _printerIp != null && _printerIp!.isNotEmpty) {
      try {
        final socket = await Socket.connect(_printerIp!, 9100,
            timeout: const Duration(seconds: 1));
        socket.destroy();
        _lastConnectionStatus = true;
      } catch (_) {
        _lastConnectionStatus = false;
      }
    } else {
      _lastConnectionStatus = await bluetooth.isConnected ?? false;
    }

    _lastConnectionCheck = now;
    return _lastConnectionStatus;
  }

  Future<void> writeBytes(List<int> bytes) async {
    debugPrint('🖨️ [PRINTER LOG] Total Raw Bytes to Send: ${bytes.length}');
    debugPrint('🖨️ [PRINTER LOG] Raw Bytes Header Snippet (first 30): ${bytes.take(30).toList()}');
    if (_isNetworkPrinter && _printerIp != null && _printerIp!.isNotEmpty) {
      try {
        final socket = await Socket.connect(_printerIp!, 9100,
            timeout: const Duration(seconds: 3));
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        debugPrint('🖨️ [PRINTER LOG] Network Print sent successfully to $_printerIp');
      } catch (e) {
        debugPrint('❌ [PRINTER ERROR] Network Print Error: $e');
      }
    } else {
      // Send in smaller 128-byte chunks for classic 58mm Bluetooth thermal printers
      const int chunkSize = 128;
      debugPrint('🖨️ [PRINTER LOG] Sending via Bluetooth in $chunkSize-byte chunks...');
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);
        await bluetooth.writeBytes(Uint8List.fromList(chunk));
        await Future.delayed(const Duration(milliseconds: 50));
      }
      debugPrint('🖨️ [PRINTER LOG] All Bluetooth chunks sent successfully!');
    }
  }

  Future<bool> attemptAutoConnect() async {
    if (kIsWeb) return false;
    
    try {
      await initPreferences();
      if (_isNetworkPrinter && _printerIp != null && _printerIp!.isNotEmpty) {
        return await connectNetwork(_printerIp!);
      }

      final alreadyConnected = await isConnected;
      if (alreadyConnected) return true;

      final prefs = await SharedPreferences.getInstance();
      final mac = prefs.getString('printer_mac');
      if (mac != null && mac.isNotEmpty) {
        final devices = await getDevices();
        final device = devices.where((d) => d.address == mac).firstOrNull;
        if (device != null) {
          return await connect(device);
        }
      }
    } catch (e) {
      debugPrint('Printer auto-connect error: $e');
    }
    return false;
  }


  String _padRight(String text, int length) {
    if (text.length >= length) return text.substring(0, length);
    return text.padRight(length);
  }

  String _padLeft(String text, int length) {
    if (text.length >= length) return text.substring(0, length);
    return text.padLeft(length);
  }

  String _justify(String left, String right, int width) {
    if (left.length + right.length >= width) {
      int availableForLeft = width - right.length - 1;
      if (availableForLeft > 0) {
        return '${left.substring(0, availableForLeft)} $right';
      }
      return left + right;
    }
    return left.padRight(width - right.length) + right;
  }


  Future<void> printReceiptImage(Uint8List pngBytes) async {
    final connected = await isConnected;
    if (!connected) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);
    List<int> bytes = [];

    var decodedImage = img.decodeImage(pngBytes);
    if (decodedImage != null) {
      final targetWidth = _paperSize == PaperSize.mm80 ? 576 : 384;
      if (decodedImage.width != targetWidth) {
        decodedImage = img.copyResize(decodedImage, width: targetWidth);
      }
      bytes += generator.imageRaster(decodedImage);
    }
    
    bytes += generator.feed(2);
    bytes += generator.cut();

    await writeBytes(bytes);
  }

  Future<void> printWebReceipt(Uint8List pngBytes, {bool is80mm = false}) async {
    try {
      final doc = pw.Document();
      final image = pw.MemoryImage(pngBytes);
      final double widthMm = is80mm ? 80.0 : 58.0;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            widthMm * PdfPageFormat.mm,
            double.infinity,
            marginAll: 0,
          ),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Bill_Receipt',
      );
    } catch (e) {
      debugPrint('Web print error: $e');
    }
  }

  Future<void> printReceipt(
      ApiToken token, ApiShopData shopData, ApiBillTemplate template) async {
    final connected = await isConnected;
    debugPrint('🖨️ [PRINTER LOG] printReceipt called. Printer Connected: $connected, Paper: $_paperSize');
    if (!connected) {
      debugPrint('❌ [PRINTER LOG] Aborting printReceipt because Bluetooth/Network printer is NOT connected!');
      return;
    }

    final profile = await CapabilityProfile.load(name: 'default');
    final generator = Generator(_paperSize, profile);
    List<int> bytes = [];
    bytes += generator.reset();
    
    // 32 characters for 58mm paper at 4.0mm height (PosTextSize.size2 = 32 dots height / 24 dots width)
    final int paperWidth = _paperSize == PaperSize.mm80 ? 48 : 32;
    const PosFontType baseFont = PosFontType.fontA;

    // Fetch global admin system settings for dynamic font size mapping
    PosTextSize titleHeight = PosTextSize.size4;
    PosTextSize bodyHeight = PosTextSize.size2;
    PosTextSize subtotalHeight = PosTextSize.size2;
    PosTextSize grandTotalHeight = PosTextSize.size3;
    PosTextSize footerHeight = PosTextSize.size2;

    PosTextSize getPosSize(double mm) {
      if (mm >= 18.0) return PosTextSize.size4;
      if (mm >= 9.0)  return PosTextSize.size3;
      if (mm >= 5.0)  return PosTextSize.size2;
      return PosTextSize.size1;
    }

    try {
      final sysSettings = await RestaurantApi.instance.fetchSystemSettings();
      titleHeight = getPosSize(sysSettings.billTitleFontSizeMm);
      bodyHeight = getPosSize(sysSettings.billBodyFontSizeMm);
      subtotalHeight = getPosSize(sysSettings.billSubtotalFontSizeMm);
      grandTotalHeight = getPosSize(sysSettings.billGrandTotalFontSizeMm);
      footerHeight = getPosSize(sysSettings.billFooterFontSizeMm);
    } catch (_) {}

    // Dynamic Style helpers mapped from Admin Settings
    PosStyles bodyStyle({PosAlign align = PosAlign.left, bool bold = false}) {
      return PosStyles(
        fontType: baseFont,
        align: align,
        height: bodyHeight,
        width: PosTextSize.size1,
        bold: bold,
      );
    }

    PosStyles subtotalStyle({PosAlign align = PosAlign.left, bool bold = false}) {
      return PosStyles(
        fontType: baseFont,
        align: align,
        height: subtotalHeight,
        width: PosTextSize.size1,
        bold: bold,
      );
    }

    PosStyles grandTotalStyle({PosAlign align = PosAlign.center, bool bold = true}) {
      return PosStyles(
        fontType: baseFont,
        align: align,
        height: grandTotalHeight,
        width: PosTextSize.size1,
        bold: bold,
      );
    }

    PosStyles footerStyle({PosAlign align = PosAlign.center, bool bold = false}) {
      return PosStyles(
        fontType: baseFont,
        align: align,
        height: footerHeight,
        width: PosTextSize.size1,
        bold: bold,
      );
    }

    // Top spacing to increase receipt height
    bytes += generator.feed(1);

    // 1. SHOP NAME HEADER - Dynamic Admin Title Height
    bytes += generator.text(shopData.name.toUpperCase(),
        styles: PosStyles(
            fontType: baseFont,
            align: PosAlign.center,
            height: titleHeight,
            width: PosTextSize.size2,
            bold: true));
    bytes += generator.feed(1);

    // 2. SUB-HEADER - TAX INVOICE
    bytes += generator.text('TAX INVOICE', styles: bodyStyle(align: PosAlign.center, bold: true));
    bytes += generator.feed(1);
    
    // Store Info - Center Aligned
    if (shopData.tagline.isNotEmpty) {
      bytes += generator.text('"${shopData.tagline}"', styles: bodyStyle(align: PosAlign.center));
    }
    if (shopData.address != null && shopData.address!.isNotEmpty) {
      bytes += generator.text(shopData.address!, styles: bodyStyle(align: PosAlign.center));
    }
    if (shopData.phone != null && shopData.phone!.isNotEmpty) {
      bytes += generator.text('Ph: ${shopData.phone}', styles: bodyStyle(align: PosAlign.center));
    }
    if (shopData.email != null && shopData.email!.isNotEmpty) {
      bytes += generator.text('Email: ${shopData.email}', styles: bodyStyle(align: PosAlign.center));
    }
    if (shopData.gstin != null && shopData.gstin!.isNotEmpty) {
      bytes += generator.text('GSTIN: ${shopData.gstin}', styles: bodyStyle(align: PosAlign.center, bold: true));
    }
    bytes += generator.text('=' * paperWidth, styles: bodyStyle());

    // 3. INVOICE & TOKEN NO.
    String invStr = 'Inv: #${token.billNumber}';
    String tokenStr = 'TOKEN: #${token.tokenNumber}';
    bytes += generator.text(_justify(invStr, tokenStr, paperWidth), styles: bodyStyle(bold: true));
    
    // DATE & CUSTOMER DETAILS
    final dtParts = token.createdAt.split('T');
    final dateStr = dtParts.isNotEmpty ? dtParts.first : '';
    bytes += generator.text('Date: $dateStr', styles: bodyStyle());
    
    if (token.customerName.isNotEmpty || token.customerPhone.isNotEmpty) {
      bytes += generator.text('-' * paperWidth, styles: bodyStyle());
      if (token.customerName.isNotEmpty) {
        bytes += generator.text('Customer: ${token.customerName}', styles: bodyStyle(bold: true));
      }
      if (token.customerPhone.isNotEmpty) {
        bytes += generator.text('Ph: ${token.customerPhone}', styles: bodyStyle());
      }
    }

    // 4. ITEMS TABLE
    bytes += generator.text('-' * paperWidth, styles: bodyStyle());
    
    int itemLen = paperWidth >= 48 ? 24 : 14;
    int qtyLen = paperWidth >= 48 ? 6 : 4;
    int rateLen = paperWidth >= 48 ? 8 : 6;
    int totalLen = paperWidth >= 48 ? 10 : 8;

    String headerStr = _padRight('Item', itemLen) + 
                       _padLeft('Qty', qtyLen) + 
                       _padLeft('Rate', rateLen) + 
                       _padLeft('Total', totalLen);
    bytes += generator.text(headerStr, styles: bodyStyle(bold: true));
    bytes += generator.text('-' * paperWidth, styles: bodyStyle());

    // Item rows
    for (final item in token.items) {
      String iStr = _padRight(item.name, itemLen);
      String qStr = _padLeft('${item.quantity}', qtyLen);
      String rStr = _padLeft(item.rate.toStringAsFixed(0), rateLen);
      String tStr = _padLeft(item.subtotal.toStringAsFixed(2), totalLen);
      bytes += generator.text('$iStr$qStr$rStr$tStr', styles: bodyStyle(bold: true));
    }
    bytes += generator.text('-' * paperWidth, styles: bodyStyle());

    // 5. SUBTOTAL & TAX (Subtotal Font Size)
    final computedSubtotal = token.items.fold(0.0, (sum, i) => sum + i.subtotal);
    final computedTax = token.grandTotal - computedSubtotal;

    bytes += generator.text(_justify('Subtotal:', computedSubtotal.toStringAsFixed(2), paperWidth), styles: subtotalStyle());
    if (computedTax > 0) {
      bytes += generator.text(_justify('Tax:', computedTax.toStringAsFixed(2), paperWidth), styles: subtotalStyle());
    }
    bytes += generator.text('=' * paperWidth, styles: bodyStyle());
    
    // GRAND TOTAL: Rs. XXX (Grand Total Font Size, Bold & Highlighted Center)
    String grandTotalText = 'GRAND TOTAL: Rs.${token.grandTotal.toStringAsFixed(2)}';
    bytes += generator.text(grandTotalText, styles: grandTotalStyle(align: PosAlign.center, bold: true));
    bytes += generator.text('=' * paperWidth, styles: bodyStyle());

    // PAYMENT MODE (CASH/UPI)
    bytes += generator.text(_justify('Payment Mode:', token.paymentMode.toUpperCase(), paperWidth), styles: bodyStyle(bold: true));

    // 6. UPI ID / SCAN TO PAY
    if (shopData.upiId != null && shopData.upiId!.isNotEmpty) {
      bytes += generator.feed(1);
      bytes += generator.text('UPI: ${shopData.upiId!}', styles: bodyStyle(align: PosAlign.center, bold: true));
      bytes += generator.text('Pay Rs.${token.grandTotal.toStringAsFixed(2)}', styles: bodyStyle(align: PosAlign.center, bold: true));
    }

    // 7. FOOTER MESSAGE & TERMS (Footer Font Size)
    if (template.footerMessage.isNotEmpty) {
      bytes += generator.feed(1);
      bytes += generator.text(template.footerMessage, styles: footerStyle(align: PosAlign.center, bold: true));
    }
    if (template.termsAndConditions.isNotEmpty) {
      bytes += generator.text(template.termsAndConditions, styles: footerStyle(align: PosAlign.center));
    }

    // Extra bottom paper feed for clean cutting
    bytes += generator.feed(4);
    bytes += generator.cut();

    await writeBytes(bytes);
  }

  Future<void> printKitchenSlip(ApiToken token) async {
    final connected = await isConnected;
    if (!connected) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);
    List<int> bytes = [];
    
    final int paperWidth = _paperSize == PaperSize.mm80 ? 60 : 32;
    const PosFontType baseFont = PosFontType.fontA;

    PosStyles receiptStyle({PosAlign align = PosAlign.left, bool bold = false, PosTextSize height = PosTextSize.size2, PosTextSize width = PosTextSize.size2}) {
      return PosStyles(
        fontType: baseFont,
        align: align,
        height: height,
        width: width,
        bold: bold,
      );
    }

    bytes += generator.text('=' * (paperWidth ~/ 2), styles: receiptStyle(align: PosAlign.center, bold: true));
    bytes += generator.text('KITCHEN SLIP',
        styles: receiptStyle(
            align: PosAlign.center,
            height: PosTextSize.size3,
            width: PosTextSize.size2,
            bold: true));
    bytes += generator.text('=' * (paperWidth ~/ 2), styles: receiptStyle(align: PosAlign.center, bold: true));
    bytes += generator.feed(1);

    String tokenStr = 'TOKEN: ${token.tokenNumber}';
    bytes += generator.text(tokenStr, styles: receiptStyle(bold: true, height: PosTextSize.size3, width: PosTextSize.size2));
    bytes += generator.text('DATE:  ${token.createdAt.split('T').first}', styles: receiptStyle());
    bytes += generator.feed(1);

    bytes += generator.text('ITEMS', styles: receiptStyle(bold: true, align: PosAlign.center));
    bytes += generator.text('-' * (paperWidth ~/ 2), styles: receiptStyle());

    for (final item in token.items) {
      bytes += generator.text('${item.quantity} x ${item.name}', styles: receiptStyle(bold: true));
    }

    bytes += generator.text('=' * (paperWidth ~/ 2), styles: receiptStyle());

    bytes += generator.feed(2);
    bytes += generator.cut();

    await writeBytes(bytes);
  }

  Future<void> printTest() async {
    final connected = await isConnected;
    if (!connected) return;

    final prefs = await SharedPreferences.getInstance();
    final double fontSize = prefs.getDouble('print_font_size') ?? (_paperSize == PaperSize.mm80 ? 55.0 : 16.0);

    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);
    List<int> bytes = [];

    final int paperWidth = _paperSize == PaperSize.mm80 ? 60 : 32;
    const PosFontType baseFont = PosFontType.fontA;

    PosStyles receiptStyle({PosAlign align = PosAlign.left, bool bold = true, PosTextSize height = PosTextSize.size3, PosTextSize width = PosTextSize.size2}) {
      return PosStyles(
        fontType: baseFont,
        align: align,
        height: height,
        width: width,
        bold: bold,
      );
    }

    final int lineDividerLen = paperWidth ~/ 2;

    bytes += generator.text('=' * lineDividerLen, styles: receiptStyle(align: PosAlign.center));
    bytes += generator.text('TEST PRINT SUCCESSFUL!',
        styles: receiptStyle(
            align: PosAlign.center,
            height: PosTextSize.size3,
            width: PosTextSize.size2,
            bold: true));
    bytes += generator.text('Font Size: ${fontSize.toInt()} px',
        styles: receiptStyle(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true));
    bytes += generator.text('Paper: ${_paperSize == PaperSize.mm80 ? "80 mm" : "58 mm"}',
        styles: receiptStyle(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true));
    bytes += generator.text('=' * lineDividerLen, styles: receiptStyle(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    await writeBytes(bytes);
  }
}