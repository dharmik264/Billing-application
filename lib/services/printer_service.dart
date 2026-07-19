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
    
    final int paperWidth = _paperSize == PaperSize.mm80 ? 48 : 32;

    // Header
    bytes += generator.text(shopData.name.toUpperCase(),
        styles: const PosStyles(
            fontType: PosFontType.fontA,
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true));
    bytes += generator.text('TAX INVOICE', styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size1, bold: true));
    
    if (shopData.tagline.isNotEmpty) {
      bytes += generator.text('"${shopData.tagline}"', styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    if (shopData.address != null && shopData.address!.isNotEmpty) {
      bytes += generator.text(shopData.address!,
          styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    if (shopData.phone != null && shopData.phone!.isNotEmpty) {
      bytes += generator.text('Ph: ${shopData.phone}',
          styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    if (shopData.email != null && shopData.email!.isNotEmpty) {
      bytes += generator.text('Email: ${shopData.email}',
          styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    if (shopData.gstin != null && shopData.gstin!.isNotEmpty) {
      bytes += generator.text('GSTIN: ${shopData.gstin}',
          styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    bytes += generator.feed(1);
    bytes += generator.text('-' * paperWidth);

    // Bill Details
    bytes += generator.row([
      PosColumn(text: 'Inv: ${token.billNumber}', width: 6, styles: const PosStyles(fontType: PosFontType.fontA)),
      PosColumn(text: 'Token: ${token.tokenNumber}', width: 6, styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.right, bold: true)),
    ]);
    final dtParts = token.createdAt.split('T');
    final dateStr = dtParts.isNotEmpty ? dtParts.first : '';
    bytes += generator.row([
      PosColumn(text: 'Date: $dateStr', width: 12, styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.right)),
    ]);
    
    if (token.customerName.isNotEmpty || token.customerPhone.isNotEmpty) {
      bytes += generator.text('-' * paperWidth);
      if (token.customerName.isNotEmpty) {
        bytes += generator.text('Customer: ${token.customerName}', styles: const PosStyles(fontType: PosFontType.fontA));
      }
      if (token.customerPhone.isNotEmpty) {
        bytes += generator.text('Ph: ${token.customerPhone}', styles: const PosStyles(fontType: PosFontType.fontA));
      }
    }
    bytes += generator.feed(1);

    // Items Header
    bytes += generator.text('-' * paperWidth);
    
    int itemLen = paperWidth == 48 ? 20 : 13;
    int qtyLen = paperWidth == 48 ? 6 : 4;
    int rateLen = paperWidth == 48 ? 10 : 7;
    int totalLen = paperWidth == 48 ? 12 : 8;

    String headerStr = _padRight('Item', itemLen) + 
                       _padLeft('Qty', qtyLen) + 
                       _padLeft('Rate', rateLen) + 
                       _padLeft('Total', totalLen);
    bytes += generator.text(headerStr, styles: const PosStyles(fontType: PosFontType.fontA, bold: true));
    bytes += generator.text('-' * paperWidth);

    // Items
    for (final item in token.items) {
      String iStr = _padRight(item.name, itemLen);
      String qStr = _padLeft('${item.quantity}', qtyLen);
      String rStr = _padLeft(item.rate.toStringAsFixed(2), rateLen);
      String tStr = _padLeft(item.subtotal.toStringAsFixed(2), totalLen);
      bytes += generator.text('$iStr$qStr$rStr$tStr', styles: const PosStyles(fontType: PosFontType.fontA));
    }
    bytes += generator.text('-' * paperWidth);

    // Totals
    final computedSubtotal = token.items.fold(0.0, (sum, i) => sum + i.subtotal);
    final computedTax = token.grandTotal - computedSubtotal;

    int totalLabelLen = paperWidth == 48 ? 36 : 24;
    int totalValueLen = paperWidth == 48 ? 12 : 8;

    bytes += generator.text(_padLeft('Subtotal: ', totalLabelLen) + _padLeft(computedSubtotal.toStringAsFixed(2), totalValueLen), styles: const PosStyles(fontType: PosFontType.fontA));
    bytes += generator.text(_padLeft('Discount: ', totalLabelLen) + _padLeft('0.00', totalValueLen), styles: const PosStyles(fontType: PosFontType.fontA));
    bytes += generator.text(_padLeft('Tax: ', totalLabelLen) + _padLeft(computedTax.toStringAsFixed(2), totalValueLen), styles: const PosStyles(fontType: PosFontType.fontA));
    bytes += generator.text(_padLeft('Round Off: ', totalLabelLen) + _padLeft('0.00', totalValueLen), styles: const PosStyles(fontType: PosFontType.fontA));
    bytes += generator.feed(1);
    
    bytes += generator.text('=' * paperWidth);
    bytes += generator.text('GRAND TOTAL: Rs.${token.grandTotal.toStringAsFixed(2)}', styles: const PosStyles(fontType: PosFontType.fontA, height: PosTextSize.size2, width: PosTextSize.size2, bold: true, align: PosAlign.center));
    bytes += generator.text('=' * paperWidth);

    bytes += generator.feed(1);
    bytes += generator.row([
      PosColumn(text: 'Payment Mode', width: 6, styles: const PosStyles(fontType: PosFontType.fontA)),
      PosColumn(text: token.paymentMode, width: 6, styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.right)),
    ]);
    bytes += generator.feed(1);

    if (shopData.upiId != null && shopData.upiId!.isNotEmpty) {
      final qrData = 'upi://pay?pa=${shopData.upiId}&pn=${Uri.encodeComponent(shopData.name)}&am=${token.grandTotal.toStringAsFixed(2)}&cu=INR';
      bytes += generator.qrcode(qrData, size: QRSize.size6);
      bytes += generator.text(shopData.upiId!, styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
      bytes += generator.text('Scan to Pay Rs. ${token.grandTotal.toStringAsFixed(2)}', styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center, bold: true));
      bytes += generator.feed(1);
    }

    if (template.footerMessage.isNotEmpty) {
      bytes += generator.text(template.footerMessage,
          styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    if (template.termsAndConditions.isNotEmpty) {
      bytes += generator.text(template.termsAndConditions,
          styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
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
    
    final int paperWidth = _paperSize == PaperSize.mm80 ? 48 : 32;

    bytes += generator.text('=' * paperWidth);
    bytes += generator.text('KITCHEN SLIP',
        styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true));
    bytes += generator.text('=' * paperWidth);
    bytes += generator.feed(1);

    bytes += generator.text('TOKEN: ${token.tokenNumber}',
        styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size1));
    bytes += generator.text('DATE:  ${token.createdAt.split('T').first}',
        styles: const PosStyles(bold: true));
    bytes += generator.feed(1);

    bytes += generator.text('ITEMS', styles: const PosStyles(bold: true, height: PosTextSize.size2));
    bytes += generator.text('-' * paperWidth);

    for (final item in token.items) {
      bytes += generator.text('${item.name} x ${item.quantity}', styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size1));
      bytes += generator.feed(1);
    }

    bytes += generator.text('=' * paperWidth);

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

    bytes += generator.text('Test Print Successful!',
        styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2));
    bytes += generator.feed(2);
    bytes += generator.cut();

    await writeBytes(bytes);
  }
}
