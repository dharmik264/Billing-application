import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'restaurant_api.dart';

class PdfReceiptService {
  static Future<Uint8List> generateReceipt(ApiToken token, {bool isThermal = true}) async {
    final pdf = pw.Document();

    final shop = await RestaurantApi.instance.fetchShop();

    final pageFormat = isThermal
        ? PdfPageFormat.roll80
        : PdfPageFormat.a4;

    pw.MemoryImage? logoImage;
    pw.ImageProvider? networkLogo;

    if (shop.logoUrl != null && shop.logoUrl!.isNotEmpty) {
      try {
        if (shop.logoUrl!.startsWith('data:image')) {
          logoImage = pw.MemoryImage(base64Decode(shop.logoUrl!.split(',').last));
        } else if (shop.logoUrl!.contains('/')) {
          networkLogo = await networkImage(RestaurantApi.instance.getMediaUrl(shop.logoUrl!));
        } else {
          logoImage = pw.MemoryImage(base64Decode(shop.logoUrl!));
        }
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          final computedSubtotal = token.items.fold(0.0, (sum, item) => sum + item.subtotal);
          final computedTax = token.grandTotal - computedSubtotal;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null || networkLogo != null) ...[
                pw.Center(
                  child: pw.ClipOval(
                    child: pw.Container(
                      width: 50,
                      height: 50,
                      child: pw.Image(logoImage ?? networkLogo!, fit: pw.BoxFit.cover),
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
              pw.Center(
                child: pw.Text(
                  shop.name.toUpperCase(),
                  style: const pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('TAX INVOICE', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
              ),
              if (shop.tagline.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text('"${shop.tagline}"', style: const pw.TextStyle(fontSize: 10))),
              ],
              if (shop.address != null && shop.address!.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text(shop.address!, style: const pw.TextStyle(fontSize: 10))),
              ],
              if (shop.phone != null && shop.phone!.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text('Ph: ${shop.phone}', style: const pw.TextStyle(fontSize: 10))),
              ],
              if (shop.email != null && shop.email!.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text('Email: ${shop.email}', style: const pw.TextStyle(fontSize: 10))),
              ],
              if (shop.gstin != null && shop.gstin!.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(child: pw.Text('GSTIN: ${shop.gstin}', style: const pw.TextStyle(fontSize: 10))),
              ],
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Inv: ${token.billNumber}'),
                  pw.Text('Token No: ${token.tokenNumber}'),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(token.customerName.isNotEmpty ? 'Customer: ${token.customerName}' : ''),
                  pw.Text('Date: ${token.createdAt.split('T').first}'),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Divider(),
              pw.SizedBox(height: 10),
              // Items
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Item', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Qty', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Price', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                    ],
                  ),
                  ...token.items.map((item) => pw.TableRow(
                    children: [
                      pw.Text(item.name),
                      pw.Text(item.quantity.toString()),
                      pw.Text(item.rate.toStringAsFixed(2)),
                      pw.Text(item.subtotal.toStringAsFixed(2), textAlign: pw.TextAlign.right),
                    ],
                  )),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:'),
                  pw.Text('Rs. ${computedSubtotal.toStringAsFixed(2)}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Discount:'),
                  pw.Text('Rs. 0.00'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tax:'),
                  pw.Text('Rs. ${computedTax.toStringAsFixed(2)}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Round Off:'),
                  pw.Text('Rs. 0.00'),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Grand Total:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text('Rs. ${token.grandTotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Mode:'),
                  pw.Text(token.paymentMode),
                ],
              ),
              pw.SizedBox(height: 20),
              if (shop.upiId != null && shop.upiId!.isNotEmpty)
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Scan to Pay', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.SizedBox(height: 5),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'upi://pay?pa=${shop.upiId}&pn=${Uri.encodeComponent(shop.name)}&am=${token.grandTotal.toStringAsFixed(2)}&cu=INR',
                        width: 100,
                        height: 100,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(shop.upiId!, style: const pw.TextStyle(fontSize: 10)),
                    ]
                  )
                ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('Thank you for your visit!', style: const pw.TextStyle(fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printReceipt(ApiToken token) async {
    final bytes = await generateReceipt(token);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Receipt_${token.id}',
    );
  }
}
