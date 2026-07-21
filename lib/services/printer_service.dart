import 'dart:typed_data';
import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    if (_isNetworkPrinter && _printerIp != null && _printerIp!.isNotEmpty) {
      try {
        final socket = await Socket.connect(_printerIp!, 9100,
            timeout: const Duration(seconds: 3));
        socket.add(bytes);
        await socket.flush();
        await socket.close();
      } catch (e) {
        // print failed
      }
    } else {
      bluetooth.writeBytes(Uint8List.fromList(bytes));
    }
  }

  Future<void> attemptAutoConnect() async {
    if (kIsWeb) return;
    
    await initPreferences();
    if (_isNetworkPrinter) return;

    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString('printer_mac');
    if (mac != null && mac.isNotEmpty) {
      final devices = await getDevices();
      final device = devices.where((d) => d.address == mac).firstOrNull;
      if (device != null) {
        await connect(device);
      }
    }
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
        return left.substring(0, availableForLeft) + ' ' + right;
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

    final decodedImage = img.decodeImage(pngBytes);
    if (decodedImage != null) {
      bytes += generator.imageRaster(decodedImage);
    }
    
    bytes += generator.feed(2);
    bytes += generator.cut();

    await writeBytes(bytes);
  }

  Future<void> printReceipt(
      ApiToken token, ApiShopData shopData, ApiBillTemplate template) async {
    final connected = await isConnected;
    if (!connected) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);
    List<int> bytes = [];
    
    // 24x48 px font size (size2): 16 characters for 58mm, 24 characters for 80mm
    final int paperWidth = _paperSize == PaperSize.mm80 ? 24 : 16;
    final PosFontType baseFont = PosFontType.fontA;

    PosStyles style24x48({PosAlign align = PosAlign.left, bool bold = false}) {
      return PosStyles(
        fontType: baseFont,
        align: align,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: bold,
      );
    }

    // Header
    bytes += generator.text(shopData.name.toUpperCase(),
        styles: style24x48(align: PosAlign.center, bold: true));
    bytes += generator.text('TAX INVOICE', styles: style24x48(align: PosAlign.center, bold: true));
    
    if (shopData.tagline.isNotEmpty) {
      bytes += generator.text('"${shopData.tagline}"', styles: style24x48(align: PosAlign.center));
    }
    if (shopData.address != null && shopData.address!.isNotEmpty) {
      bytes += generator.text(shopData.address!, styles: style24x48(align: PosAlign.center));
    }
    if (shopData.phone != null && shopData.phone!.isNotEmpty) {
      bytes += generator.text('Ph: ${shopData.phone}', styles: style24x48(align: PosAlign.center));
    }
    if (shopData.email != null && shopData.email!.isNotEmpty) {
      bytes += generator.text('Email: ${shopData.email}', styles: style24x48(align: PosAlign.center));
    }
    if (shopData.gstin != null && shopData.gstin!.isNotEmpty) {
      bytes += generator.text('GSTIN: ${shopData.gstin}', styles: style24x48(align: PosAlign.center));
    }
    bytes += generator.feed(1);
    bytes += generator.text('-' * paperWidth, styles: style24x48());

    // Bill Details
    String invStr = 'Inv:${token.billNumber}';
    String tokenStr = 'Tkn:${token.tokenNumber}';
    bytes += generator.text(_justify(invStr, tokenStr, paperWidth), styles: style24x48(bold: true));
    
    final dtParts = token.createdAt.split('T');
    final dateStr = dtParts.isNotEmpty ? dtParts.first : '';
    bytes += generator.text('Date: $dateStr', styles: style24x48());
    
    if (token.customerName.isNotEmpty || token.customerPhone.isNotEmpty) {
      bytes += generator.text('-' * paperWidth, styles: style24x48());
      if (token.customerName.isNotEmpty) {
        bytes += generator.text('Name: ${token.customerName}', styles: style24x48());
      }
      if (token.customerPhone.isNotEmpty) {
        bytes += generator.text('Ph: ${token.customerPhone}', styles: style24x48());
      }
    }
    bytes += generator.feed(1);

    // Items Header
    bytes += generator.text('-' * paperWidth, styles: style24x48());
    bytes += generator.text('ITEMS', styles: style24x48(align: PosAlign.center, bold: true));
    bytes += generator.text('-' * paperWidth, styles: style24x48());

    // Items (2 lines for narrow 16 char line)
    for (final item in token.items) {
      bytes += generator.text(item.name, styles: style24x48(bold: true));
      String qtyStr = '${item.quantity} x ${item.rate.toStringAsFixed(0)}';
      String totalStr = item.subtotal.toStringAsFixed(2);
      bytes += generator.text(_justify(qtyStr, totalStr, paperWidth), styles: style24x48());
    }
    bytes += generator.text('-' * paperWidth, styles: style24x48());

    // Totals
    final computedSubtotal = token.items.fold(0.0, (sum, i) => sum + i.subtotal);
    final computedTax = token.grandTotal - computedSubtotal;

    bytes += generator.text(_justify('Subtotal:', computedSubtotal.toStringAsFixed(2), paperWidth), styles: style24x48());
    bytes += generator.text(_justify('Discount:', '0.00', paperWidth), styles: style24x48());
    bytes += generator.text(_justify('Tax:', computedTax.toStringAsFixed(2), paperWidth), styles: style24x48());
    bytes += generator.text(_justify('Round Off:', '0.00', paperWidth), styles: style24x48());
    bytes += generator.feed(1);
    
    bytes += generator.text('=' * paperWidth, styles: style24x48());
    bytes += generator.text(_justify('TOTAL:', token.grandTotal.toStringAsFixed(2), paperWidth), styles: style24x48(bold: true));
    bytes += generator.text('=' * paperWidth, styles: style24x48());

    bytes += generator.feed(1);
    bytes += generator.text(_justify('Pay Mode:', token.paymentMode, paperWidth), styles: style24x48());
    bytes += generator.feed(1);

    if (shopData.upiId != null && shopData.upiId!.isNotEmpty) {
      final qrData = 'upi://pay?pa=${shopData.upiId}&pn=${Uri.encodeComponent(shopData.name)}&am=${token.grandTotal.toStringAsFixed(2)}&cu=INR';
      bytes += generator.qrcode(qrData, size: QRSize.size6);
      bytes += generator.text(shopData.upiId!, styles: style24x48(align: PosAlign.center));
      bytes += generator.text('Scan to Pay Rs. ${token.grandTotal.toStringAsFixed(2)}', styles: style24x48(align: PosAlign.center, bold: true));
      bytes += generator.feed(1);
    }

    if (template.footerMessage.isNotEmpty) {
      bytes += generator.text(template.footerMessage, styles: style24x48(align: PosAlign.center));
    }
    if (template.termsAndConditions.isNotEmpty) {
      bytes += generator.text(template.termsAndConditions, styles: style24x48(align: PosAlign.center));
    }

    bytes += generator.feed(2);
    bytes += generator.cut();

    await writeBytes(bytes);
  }

  Future<void> printKitchenSlip(ApiToken token) async {
    final connected = await isConnected;
    if (!connected) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);
    List<int> bytes = [];
    
    final int paperWidth = _paperSize == PaperSize.mm80 ? 24 : 16;
    final PosFontType baseFont = PosFontType.fontA;

    PosStyles style24x48({PosAlign align = PosAlign.left, bool bold = false}) {
      return PosStyles(
        fontType: baseFont,
        align: align,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: bold,
      );
    }

    bytes += generator.text('=' * paperWidth, styles: style24x48());
    bytes += generator.text('KITCHEN SLIP',
        styles: style24x48(
            align: PosAlign.center,
            bold: true));
    bytes += generator.text('=' * paperWidth, styles: style24x48());
    bytes += generator.feed(1);

    String tokenStr = 'TOKEN: ${token.tokenNumber}';
    bytes += generator.text(tokenStr, styles: style24x48(bold: true));
    bytes += generator.text('DATE:  ${token.createdAt.split('T').first}', styles: style24x48());
    bytes += generator.feed(1);

    bytes += generator.text('ITEMS', styles: style24x48(bold: true, align: PosAlign.center));
    bytes += generator.text('-' * paperWidth, styles: style24x48());

    for (final item in token.items) {
      bytes += generator.text('${item.quantity} x ${item.name}', styles: style24x48(bold: true));
    }

    bytes += generator.text('=' * paperWidth, styles: style24x48());

    bytes += generator.feed(2);
    bytes += generator.cut();

    await writeBytes(bytes);
  }
  Future<void> printTest() async {
    final connected = await isConnected;
    if (!connected) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);
    List<int> bytes = [];

    final int paperWidth = _paperSize == PaperSize.mm80 ? 24 : 16;
    final PosFontType baseFont = PosFontType.fontA;

    PosStyles style24x48({PosAlign align = PosAlign.left, bool bold = false}) {
      return PosStyles(
        fontType: baseFont,
        align: align,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: bold,
      );
    }

    bytes += generator.text('=' * paperWidth, styles: style24x48(align: PosAlign.center, bold: true));
    bytes += generator.text('Test Print Successful!',
        styles: style24x48(
            align: PosAlign.center,
            bold: true));
    bytes += generator.text('=' * paperWidth, styles: style24x48(align: PosAlign.center, bold: true));
    bytes += generator.feed(2);
    bytes += generator.cut();

    await writeBytes(bytes);
  }
}
