import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document();

  // Mock Data
  const shopName = 'DHARMIK ENTERPRISES';
  const shopAddress = '123, Main Market, Surat, Gujarat - 395006';
  const shopGst = '24AAAAA0000A1Z5';

  const customerName = 'Rahul Patel';
  const customerNumber = '+91 9876543210';
  const customerAddress = '45, VIP Road, Vesu, Surat';
  const customerGst = '24BBBBB1111B1Z6';

  const tokenNumber = 'T-105';
  const billNumber = 'INV-2026-001';
  const billDate = '04/09/2026';

  const items = [
    {'name': 'Premium Widget', 'qty': 2, 'rate': 1500.00, 'amount': 3000.00},
    {'name': 'Super Gadget', 'qty': 1, 'rate': 4500.00, 'amount': 4500.00},
    {'name': 'Extra Cable', 'qty': 3, 'rate': 200.00, 'amount': 600.00},
  ];

  const subTotal = 8100.00;
  const gst = 405.00;
  const finalTotal = 8505.00;
  const amountInWords = 'Eight Thousand Five Hundred Five Only';
  const upiId = 'dharmik@okhdfcbank';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // HEADER
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(shopName, style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 4),
                  pw.Text('GSTIN: $shopGst', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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
                      pw.Text('Name: $customerName'),
                      pw.SizedBox(height: 3),
                      pw.Text('Phone: $customerNumber'),
                      pw.SizedBox(height: 3),
                      pw.Text('Address: $customerAddress'),
                      pw.SizedBox(height: 3),
                      pw.Text('GSTIN: $customerGst'),
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
                      pw.Text('Bill No: $billNumber'),
                      pw.SizedBox(height: 3),
                      pw.Text('Date: $billDate'),
                      pw.SizedBox(height: 3),
                      pw.Text('Token No: $tokenNumber'),
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
              headers: const ['Sr No.', 'Item Name', 'Qty', 'Rate', 'Amount'],
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
                items.length,
                (index) => [
                  '${index + 1}',
                  items[index]['name'] as String,
                  items[index]['qty'].toString(),
                  (items[index]['rate'] as double).toStringAsFixed(2),
                  (items[index]['amount'] as double).toStringAsFixed(2),
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
                          pw.Text(subTotal.toStringAsFixed(2)),
                        ]
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('GST:'),
                          pw.Text(gst.toStringAsFixed(2)),
                        ]
                      ),
                      pw.SizedBox(height: 6),
                      pw.Divider(thickness: 1),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Final Total:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                          pw.Text(finalTotal.toStringAsFixed(2), style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
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
                      pw.Text('Scan to Pay', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.SizedBox(height: 8),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'upi://pay?pa=$upiId&pn=$shopName&am=$finalTotal&cu=INR',
                        width: 80,
                        height: 80,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('UPI ID: $upiId', style: const pw.TextStyle(fontSize: 10)),
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
                      pw.Text(amountInWords, style: const pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
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
      },
    ),
  );

  final file = File('sample_a4_bill.pdf');
  await file.writeAsBytes(await pdf.save());
  // ignore: avoid_print
  print('PDF saved to ${file.absolute.path}');
}
