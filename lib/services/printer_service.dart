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
        debugPrint('❌ [PRINTER LOG] Aborting printReceipt because printer is NOT connected!');
        return;
      }

      if (_isNetworkPrinter && _printerIp != null && _printerIp!.isNotEmpty) {
        final profile = await CapabilityProfile.load(name: 'default');
        final generator = Generator(_paperSize, profile);
        List<int> bytes = [];
        bytes += generator.reset();
        bytes += generator.text(shopData.name.toUpperCase(), styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
        bytes += generator.text('TAX INVOICE', styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.text('=' * 32);
        bytes += generator.text(_justify('Inv: #${token.billNumber}', 'TOKEN: #${token.tokenNumber}', 32));
        bytes += generator.text('-' * 32);
        for (final item in token.items) {
          bytes += generator.text('${item.name} x${item.quantity}  Rs.${item.subtotal.toStringAsFixed(2)}');
        }
        bytes += generator.text('=' * 32);
        bytes += generator.text('GRAND TOTAL: Rs.${token.grandTotal.toStringAsFixed(2)}', styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.feed(3);
        bytes += generator.cut();
        await writeBytes(bytes);
        return;
      }

      // ── Native Direct Bluetooth Text Printing (Guaranteed 0 Garbage Characters) ──
      debugPrint('🖨️ [PRINTER LOG] Printing via Native Bluetooth Direct Text Stream...');
      
      try {
        // 1. Shop Name Header (Large Size 2)
        bluetooth
          ..printCustom(shopData.name.toUpperCase(), 2, 1) // Large Bold (Size 2)
          ..printCustom('TAX INVOICE', 1, 1); // Medium (Size 1)
        
        if (shopData.tagline.isNotEmpty) {
          bluetooth.printCustom('"${shopData.tagline}"', 1, 1);
        }
        if (shopData.address != null && shopData.address!.isNotEmpty) {
          bluetooth.printCustom(shopData.address!, 1, 1);
        }
        if (shopData.phone != null && shopData.phone!.isNotEmpty) {
          bluetooth.printCustom('Ph: ${shopData.phone}', 1, 1);
        }
        if (shopData.gstin != null && shopData.gstin!.isNotEmpty) {
          bluetooth.printCustom('GSTIN: ${shopData.gstin}', 1, 1);
        }
        bluetooth.printCustom('=' * 32, 1, 1);

        // 2. Invoice & Token Details (Increased Size 1 & Size 2)
        String invStr = 'Inv: #${token.billNumber}';
        String tokenStr = 'TOKEN: #${token.tokenNumber}';
        bluetooth.printCustom(_justify(invStr, tokenStr, 32), 2, 0);

        final dtParts = token.createdAt.split('T');
        final dateStr = dtParts.isNotEmpty ? dtParts.first : '';
        bluetooth.printCustom('Date: $dateStr', 1, 0);

        if (token.customerName.isNotEmpty || token.customerPhone.isNotEmpty) {
          bluetooth.printCustom('-' * 32, 1, 0);
          if (token.customerName.isNotEmpty) {
            bluetooth.printCustom('Customer: ${token.customerName}', 2, 0);
          }
          if (token.customerPhone.isNotEmpty) {
            bluetooth.printCustom('Ph: ${token.customerPhone}', 1, 0);
          }
        }

        // 3. Items Table Header (Increased to Size 2)
        bluetooth.printCustom('-' * 32, 1, 0);
        String headerStr = _padRight('Item', 14) + 
                          _padLeft('Qty', 4) + 
                          _padLeft('Rate', 6) + 
                          _padLeft('Total', 8);
        bluetooth
          ..printCustom(headerStr, 2, 0)
          ..printCustom('-' * 32, 1, 0);

        // Item Rows (Increased to Size 1)
        for (final item in token.items) {
          String iStr = _padRight(item.name, 14);
          String qStr = _padLeft('${item.quantity}', 4);
          String rStr = _padLeft(item.rate.toStringAsFixed(0), 6);
          String tStr = _padLeft(item.subtotal.toStringAsFixed(2), 8);
          bluetooth.printCustom('$iStr$qStr$rStr$tStr', 1, 0);
        }
        bluetooth.printCustom('-' * 32, 1, 0);

        // 4. Subtotal & Totals (Increased Subtotal to Size 2, Grand Total to Size 3)
        final computedSubtotal = token.items.fold(0.0, (sum, i) => sum + i.subtotal);
        final computedTax = token.grandTotal - computedSubtotal;

        bluetooth.printCustom(_justify('Subtotal:', computedSubtotal.toStringAsFixed(2), 32), 1, 0);
        if (computedTax > 0) {
          bluetooth.printCustom(_justify('Tax:', computedTax.toStringAsFixed(2), 32), 1, 0);
        }
        bluetooth
          ..printCustom('=' * 32, 1, 0)
          ..printCustom('GRAND TOTAL: Rs.${token.grandTotal.toStringAsFixed(2)}', 2, 1) // Large Size 2
          ..printCustom('=' * 32, 1, 0)
          ..printCustom(_justify('Payment Mode:', token.paymentMode.toUpperCase(), 32), 2, 0);

        if (shopData.upiId != null && shopData.upiId!.isNotEmpty) {
          bluetooth
            ..printNewLine()
            ..printCustom('UPI: ${shopData.upiId!}', 2, 1)
            ..printCustom('Pay Rs.${token.grandTotal.toStringAsFixed(2)}', 2, 1);
        }

        if (template.footerMessage.isNotEmpty) {
          bluetooth
            ..printNewLine()
            ..printCustom(template.footerMessage, 2, 1);
        }
        if (template.termsAndConditions.isNotEmpty) {
          bluetooth.printCustom(template.termsAndConditions, 1, 1);
        }

        bluetooth
          ..printNewLine()
          ..printNewLine();
        debugPrint('🖨️ [PRINTER LOG] Native Bluetooth Text Receipt Print Complete!');
      } catch (e) {
        debugPrint('❌ [PRINTER LOG] Direct Bluetooth Print Error: $e');
      }
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

      if (_isNetworkPrinter && _printerIp != null && _printerIp!.isNotEmpty) {
        final profile = await CapabilityProfile.load(name: 'default');
        final generator = Generator(_paperSize, profile);
        List<int> bytes = [];
        bytes += generator.reset();
        bytes += generator.text('TEST PRINT SUCCESSFUL!', styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size4, width: PosTextSize.size2, bold: true));
        bytes += generator.text('JUMBO MAX FONT (20mm)', styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size3, width: PosTextSize.size1, bold: true));
        bytes += generator.feed(2);
        bytes += generator.cut();
        await writeBytes(bytes);
        return;
      }

      // Native Bluetooth Test Print with Jumbo Max (Size 3)
      try {
        bluetooth
          ..printCustom('=' * 32, 0, 1)
          ..printCustom('TEST PRINT', 3, 1) // Jumbo Max (Size 3)
          ..printCustom('JUMBO MAX FONT', 3, 1) // Jumbo Max (Size 3)
          ..printCustom('20mm - 24mm', 2, 1)
          ..printCustom('=' * 32, 0, 1)
          ..printNewLine()
          ..printNewLine();
        debugPrint('🖨️ [PRINTER LOG] Jumbo Max Test Print Sent Successfully!');
      } catch (e) {
        debugPrint('❌ [PRINTER LOG] Test Print Error: $e');
      }
    }
  }