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

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          final computedSubtotal = token.items.fold(0.0, (sum, item) => sum + item.subtotal);
          final computedTax = token.grandTotal - computedSubtotal;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'RESTAURANT RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Token No: ${token.tokenNumber}'),
                  pw.Text('Date: ${token.createdAt.length >= 10 ? token.createdAt.substring(0, 10) : token.createdAt}'),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text('Customer: ${token.customerName}'),
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
                      pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
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
                  pw.Text(computedSubtotal.toStringAsFixed(2)),
                ],
              ),
              if (computedTax > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tax:'),
                    pw.Text(computedTax.toStringAsFixed(2)),
                  ],
                ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text(token.grandTotal.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                ],
              ),
              pw.SizedBox(height: 20),
              if (shop.upiId != null && shop.upiId!.isNotEmpty)
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('Scan to Pay', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
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
