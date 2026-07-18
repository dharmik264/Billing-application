import re

with open('lib/services/printer_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Define the new printReceipt and printKitchenSlip methods
new_methods = '''  String _padRight(String text, int length) {
    if (text.length >= length) return text.substring(0, length);
    return text.padRight(length);
  }

  String _padLeft(String text, int length) {
    if (text.length >= length) return text.substring(0, length);
    return text.padLeft(length);
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
      bytes += generator.text('""', styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    if (shopData.address != null && shopData.address!.isNotEmpty) {
      bytes += generator.text(shopData.address!,
          styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    if (shopData.phone != null && shopData.phone!.isNotEmpty) {
      bytes += generator.text('Ph: ',
          styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    if (shopData.email != null && shopData.email!.isNotEmpty) {
      bytes += generator.text('Email: ',
          styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    if (shopData.gstin != null && shopData.gstin!.isNotEmpty) {
      bytes += generator.text('GSTIN: ',
          styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
    }
    bytes += generator.feed(1);
    bytes += generator.text('-' * paperWidth);

    // Bill Details
    bytes += generator.row([
      PosColumn(text: 'Inv: ', width: 6, styles: const PosStyles(fontType: PosFontType.fontA)),
      PosColumn(text: 'Token: ', width: 6, styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.right, bold: true)),
    ]);
    final dtParts = token.createdAt.split('T');
    final dateStr = dtParts.isNotEmpty ? dtParts.first : '';
    bytes += generator.row([
      PosColumn(text: 'Date: ', width: 12, styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.right)),
    ]);
    
    if (token.customerName.isNotEmpty || token.customerPhone.isNotEmpty) {
      bytes += generator.text('-' * paperWidth);
      if (token.customerName.isNotEmpty) {
        bytes += generator.text('Customer: ', styles: const PosStyles(fontType: PosFontType.fontA));
      }
      if (token.customerPhone.isNotEmpty) {
        bytes += generator.text('Ph: ', styles: const PosStyles(fontType: PosFontType.fontA));
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
      String qStr = _padLeft('', qtyLen);
      String rStr = _padLeft(item.rate.toStringAsFixed(2), rateLen);
      String tStr = _padLeft(item.subtotal.toStringAsFixed(2), totalLen);
      bytes += generator.text('', styles: const PosStyles(fontType: PosFontType.fontA));
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
    bytes += generator.text('GRAND TOTAL : Rs.', styles: const PosStyles(fontType: PosFontType.fontA, height: PosTextSize.size2, width: PosTextSize.size2, bold: true, align: PosAlign.center));
    bytes += generator.text('=' * paperWidth);

    bytes += generator.feed(1);
    bytes += generator.row([
      PosColumn(text: 'Payment Mode', width: 6, styles: const PosStyles(fontType: PosFontType.fontA)),
      PosColumn(text: token.paymentMode, width: 6, styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.right)),
    ]);
    bytes += generator.feed(1);

    if (shopData.upiId != null && shopData.upiId!.isNotEmpty) {
      final qrData = 'upi://pay?pa=&pn=&am=&cu=INR';
      bytes += generator.qrcode(qrData, size: QRSize.Size6);
      bytes += generator.text(shopData.upiId!, styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center));
      bytes += generator.text('Scan to Pay Rs. ', styles: const PosStyles(fontType: PosFontType.fontA, align: PosAlign.center, bold: true));
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

    bytes += generator.text('TOKEN : ',
        styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size1));
    bytes += generator.text('DATE  : ',
        styles: const PosStyles(bold: true));
    bytes += generator.feed(1);

    bytes += generator.text('ITEMS', styles: const PosStyles(bold: true, height: PosTextSize.size2));
    bytes += generator.text('-' * paperWidth);

    for (final item in token.items) {
      bytes += generator.text(' x ', styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size1));
      bytes += generator.feed(1);
    }

    bytes += generator.text('=' * paperWidth);

    bytes += generator.feed(2);
    bytes += generator.cut();

    await writeBytes(bytes);
  }'''

# Extract content before printReceipt and after printKitchenSlip
start_idx = content.find('  Future<void> printReceipt')
end_idx = content.find('  Future<void> printTest')

new_content = content[:start_idx] + new_methods + '\n' + content[end_idx:]

with open('lib/services/printer_service.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)
