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
        margin: isThermal ? const pw.EdgeInsets.all(0) : const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          final computedSubtotal = token.items.fold(0.0, (sum, item) => sum + item.subtotal);
          final computedTax = token.grandTotal - computedSubtotal;

          if (!isThermal) {
            return _buildA4Layout(
              shop: shop,
              token: token,
              computedSubtotal: computedSubtotal,
              computedTax: computedTax,
              logoImage: logoImage,
              networkLogo: networkLogo,
            );
          }

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
              if (token.customerPhone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Ph: ${token.customerPhone}'),
              ],
              if (token.customerAddress.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Address: ${token.customerAddress}'),
              ],
              if (token.customerGstNumber.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Cust GSTIN: ${token.customerGstNumber}'),
              ],
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

  static String _amountToWords(double amount) {
    if (amount == 0) return 'Zero Only';
    
    final ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 
                  'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    
    String convert(int n) {
      if (n < 20) return ones[n];
      if (n < 100) return '${tens[n ~/ 10]}${n % 10 != 0 ? ' ${ones[n % 10]}' : ''}';
      if (n < 1000) return '${ones[n ~/ 100]} Hundred${n % 100 != 0 ? ' ${convert(n % 100)}' : ''}';
      if (n < 100000) return '${convert(n ~/ 1000)} Thousand${n % 1000 != 0 ? ' ${convert(n % 1000)}' : ''}';
      if (n < 10000000) return '${convert(n ~/ 100000)} Lakh${n % 100000 != 0 ? ' ${convert(n % 100000)}' : ''}';
      return '${convert(n ~/ 10000000)} Crore${n % 10000000 != 0 ? ' ${convert(n % 10000000)}' : ''}';
    }

    int integerPart = amount.truncate();
    int decimalPart = ((amount - integerPart) * 100).round();
    
    String result = '${convert(integerPart)} Rupees';
    if (decimalPart > 0) {
      result += ' and ${convert(decimalPart)} Paise';
    }
    return '$result Only';
  }

  static pw.Widget _buildA4Layout({
    required ApiShopData shop,
    required ApiToken token,
    required double computedSubtotal,
    required double computedTax,
    pw.MemoryImage? logoImage,
    pw.ImageProvider? networkLogo,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // HEADER
        pw.Center(
          child: pw.Column(
            children: [
              if (logoImage != null || networkLogo != null) ...[
                pw.ClipOval(
                  child: pw.Container(
                    width: 50,
                    height: 50,
                    child: pw.Image(logoImage ?? networkLogo!, fit: pw.BoxFit.cover),
                  ),
                ),
                pw.SizedBox(height: 6),
              ],
              pw.Text(shop.name.toUpperCase(), style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              if (shop.address != null && shop.address!.isNotEmpty)
                pw.Text(shop.address!, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 4),
              if (shop.gstin != null && shop.gstin!.isNotEmpty)
                pw.Text('GSTIN: ${shop.gstin}', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ]
          )
        ),
        pw.SizedBox(height: 15),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 15),

        // TOP SECTION (Customer Info & Bill Info)
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Side (Customer)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Billed To:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.SizedBox(height: 8),
                  pw.Text('Name: ${token.customerName.isNotEmpty ? token.customerName : 'Walk-in Customer'}'),
                  pw.SizedBox(height: 3),
                  if (token.customerPhone.isNotEmpty) pw.Text('Phone: ${token.customerPhone}'),
                  if (token.customerPhone.isNotEmpty) pw.SizedBox(height: 3),
                  if (token.customerAddress.isNotEmpty) pw.Text('Address: ${token.customerAddress}'),
                  if (token.customerAddress.isNotEmpty) pw.SizedBox(height: 3),
                  if (token.customerGstNumber.isNotEmpty) pw.Text('GSTIN: ${token.customerGstNumber}'),
                ]
              )
            ),
            // Partition Line
            pw.Container(width: 1, height: 100, color: PdfColors.black, margin: const pw.EdgeInsets.symmetric(horizontal: 20)),
            // Right Side (Bill Info)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Invoice Details:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.SizedBox(height: 8),
                  pw.Text('Bill No: ${token.billNumber}'),
                  pw.SizedBox(height: 3),
                  pw.Text('Date: ${token.createdAt.split('T').first}'),
                  pw.SizedBox(height: 3),
                  pw.Text('Token No: ${token.tokenNumber}'),
                ]
              )
            ),
          ]
        ),
        pw.SizedBox(height: 15),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 15),

        // TABLE
        pw.TableHelper.fromTextArray(
          headers: ['Sr No.', 'Item Name', 'Qty', 'Rate', 'Amount'],
          headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
          },
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.center,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
          data: List<List<String>>.generate(
            token.items.length,
            (index) => [
              '${index + 1}',
              token.items[index].name,
              token.items[index].quantity.toString(),
              token.items[index].rate.toStringAsFixed(2),
              token.items[index].subtotal.toStringAsFixed(2),
            ],
          ),
        ),
        pw.SizedBox(height: 15),

        // TOTALS (Below Table, Right Side)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total:'),
                      pw.Text(computedSubtotal.toStringAsFixed(2)),
                    ]
                  ),
                  pw.SizedBox(height: 6),
                  if (computedTax > 0) ...[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('GST:'),
                        pw.Text(computedTax.toStringAsFixed(2)),
                      ]
                    ),
                    pw.SizedBox(height: 6),
                  ],
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Final Total:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text(token.grandTotal.toStringAsFixed(2), style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ]
                  ),
                ]
              )
            )
          ]
        ),
        pw.SizedBox(height: 30),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 20),

        // FOOTER SECTION
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left Side (UPI & QR)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (shop.upiId != null && shop.upiId!.isNotEmpty) ...[
                    pw.Text('Scan to Pay', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.SizedBox(height: 8),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'upi://pay?pa=${shop.upiId}&pn=${Uri.encodeComponent(shop.name)}&am=${token.grandTotal.toStringAsFixed(2)}&cu=INR',
                      width: 80,
                      height: 80,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('UPI ID: ${shop.upiId}', style: const pw.TextStyle(fontSize: 10)),
                  ]
                ]
              )
            ),
            // Partition Line
            pw.Container(width: 1, height: 130, color: PdfColors.black, margin: const pw.EdgeInsets.symmetric(horizontal: 20)),
            // Right Side (Amount in Words)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.start,
                children: [
                  pw.Text('Amount in Words:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text(_amountToWords(token.grandTotal), style: const pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
                  pw.SizedBox(height: 60), // Spacer before signature
                  pw.Align(
                    alignment: pw.Alignment.bottomRight,
                    child: pw.Text('Authorized Signatory', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold))
                  )
                ]
              )
            ),
          ]
        ),
      ],
    );
  }

  static Future<void> printReceipt(ApiToken token) async {
    final bytes = await generateReceipt(token);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Receipt_${token.id}',
    );
  }
}
