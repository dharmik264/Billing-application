import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'export.dart';

class PdfTokenRow {
  final String billNumber;
  final String tokenNumber;
  final String customerName;
  final String customerPhone;
  final String dateTime;
  final double amount;
  final String payment;
  final String status;
  final String items;
  final String orderType;

  PdfTokenRow({
    required this.billNumber,
    required this.tokenNumber,
    required this.customerName,
    required this.customerPhone,
    required this.dateTime,
    required this.amount,
    required this.payment,
    required this.status,
    required this.items,
    this.orderType = '',
  });
}

class PdfExport {
  static Future<String> exportReport({
    required List<PdfTokenRow> tokens,
    required String rangeLabel,
    required String shopName,
    required double totalAmount,
  }) async {
    final pdf = pw.Document();

    int totalBills = tokens.length;
    int completedCount =
        tokens.where((t) => t.status.toLowerCase() == 'completed').length;
    int cancelledCount =
        tokens.where((t) => t.status.toLowerCase() == 'cancelled').length;

    double cashTotal = tokens
        .where((t) =>
            t.payment.toLowerCase() == 'cash' &&
            t.status.toLowerCase() != 'cancelled')
        .fold(0.0, (sum, t) => sum + t.amount);
    double onlineTotal = tokens
        .where((t) =>
            t.payment.toLowerCase() != 'cash' &&
            t.status.toLowerCase() != 'cancelled')
        .fold(0.0, (sum, t) => sum + t.amount);

    double realTotal = cashTotal + onlineTotal;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
            ),
          );
        },
        build: (pw.Context context) => [
          _buildHeader(shopName, rangeLabel),
          pw.SizedBox(height: 20),
          _buildSummaryCards(
              totalBills, totalAmount, completedCount, cancelledCount),
          pw.SizedBox(height: 20),
          _buildPaymentBreakdown(cashTotal, onlineTotal, realTotal),
          pw.SizedBox(height: 20),
          pw.Text('Transaction Details',
              style:
                  const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildTransactionTable(tokens),
        ],
      ),
    );

    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final rangeSafe =
        rangeLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final fileName = 'report_${rangeSafe}_$dateStr.pdf';

    final Uint8List bytes = await pdf.save();
    await downloadPdf(bytes, fileName);

    return fileName;
  }

  static pw.Widget _buildHeader(String shopName, String rangeLabel) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final hour =
        now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final suffix = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $suffix';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(shopName,
                style: const pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800)),
            pw.SizedBox(height: 4),
            pw.Text('Analytics Report',
                style:
                    const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Range: $rangeLabel',
                style:
                    const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Generated: $dateStr, $timeStr',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSummaryCards(int totalBills, double totalAmount,
      int completedCount, int cancelledCount) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _summaryCard('Total Bills', totalBills.toString(), PdfColors.blue50),
        _summaryCard('Total Sales', 'Rs. ${totalAmount.toStringAsFixed(2)}',
            PdfColors.green50),
        _summaryCard('Completed', completedCount.toString(), PdfColors.teal50),
        _summaryCard('Cancelled', cancelledCount.toString(), PdfColors.red50),
      ],
    );
  }

  static pw.Widget _summaryCard(String title, String value, PdfColor bgColor) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 4),
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style:
                    const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPaymentBreakdown(
      double cashTotal, double onlineTotal, double realTotal) {
    final cashPct = realTotal > 0
        ? (cashTotal / realTotal * 100).toStringAsFixed(1)
        : '0.0';
    final onlinePct = realTotal > 0
        ? (onlineTotal / realTotal * 100).toStringAsFixed(1)
        : '0.0';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          pw.Column(
            children: [
              pw.Text('Cash Total',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text('Rs. ${cashTotal.toStringAsFixed(2)} ($cashPct%)',
                  style: const pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Column(
            children: [
              pw.Text('Online/UPI Total',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text('Rs. ${onlineTotal.toStringAsFixed(2)} ($onlinePct%)',
                  style: const pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTransactionTable(List<PdfTokenRow> tokens) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2), // Bill No
        1: pw.FlexColumnWidth(1.2), // Token No
        2: pw.FlexColumnWidth(1.5), // Type
        3: pw.FlexColumnWidth(2.0), // Customer
        4: pw.FlexColumnWidth(2.0), // Date
        5: pw.FlexColumnWidth(3.5), // Items (given more width for full bill)
        6: pw.FlexColumnWidth(1.5), // Amount
        7: pw.FlexColumnWidth(1.5), // Payment
        8: pw.FlexColumnWidth(1.2), // Status
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue800),
          children: [
            _headerCell('Bill No'),
            _headerCell('Token No'),
            _headerCell('Type'),
            _headerCell('Customer'),
            _headerCell('Date & Time'),
            _headerCell('Items'),
            _headerCell('Amount', align: pw.TextAlign.right),
            _headerCell('Payment Mode', align: pw.TextAlign.center),
            _headerCell('Status', align: pw.TextAlign.center),
          ],
        ),
        for (var t in tokens)
          pw.TableRow(
            children: [
              _dataCell(t.billNumber),
              _dataCell(t.tokenNumber),
              _dataCell(t.orderType),
              _dataCell(t.customerName.isEmpty
                  ? '-'
                  : '${t.customerName}\n${t.customerPhone}'),
              _dataCell(t.dateTime),
              _dataCell(t.items.isEmpty ? '-' : t.items),
              _dataCell('Rs. ${t.amount.toStringAsFixed(2)}',
                  align: pw.TextAlign.right),
              _dataCell(t.payment, align: pw.TextAlign.center),
              _statusBadge(t.status),
            ],
          ),
      ],
    );
  }

  static pw.Widget _headerCell(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _dataCell(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  static pw.Widget _statusBadge(String status) {
    PdfColor bgColor;
    PdfColor textColor;

    if (status.toLowerCase() == 'completed') {
      bgColor = PdfColors.green50;
      textColor = PdfColors.green800;
    } else if (status.toLowerCase() == 'cancelled') {
      bgColor = PdfColors.red50;
      textColor = PdfColors.red800;
    } else {
      bgColor = PdfColors.orange50;
      textColor = PdfColors.orange800;
    }

    return pw.Container(
      margin: const pw.EdgeInsets.all(4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Text(
        status,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
            fontSize: 8, fontWeight: pw.FontWeight.bold, color: textColor),
      ),
    );
  }

  static Future<String> exportItemDetailReport({
    required List<PdfItemDetailRow> items,
    required String rangeLabel,
    required String shopName,
  }) async {
    final pdf = pw.Document();
    final totalQty = items.fold(0, (sum, i) => sum + i.quantity);
    final totalRev = items.fold(0.0, (sum, i) => sum + i.subtotal);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(shopName, '$rangeLabel (Item Details - Date Order)'),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryCard('Total Transactions', items.length.toString(), PdfColors.blue50),
              _summaryCard('Total Quantity Sold', totalQty.toString(), PdfColors.teal50),
              _summaryCard('Total Revenue', 'Rs. ${totalRev.toStringAsFixed(2)}', PdfColors.green50),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(3),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(1.2),
              5: pw.FlexColumnWidth(1.5),
              6: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _headerCell('Date/Time'),
                  _headerCell('Bill No'),
                  _headerCell('Item Name'),
                  _headerCell('Category'),
                  _headerCell('Qty', align: pw.TextAlign.center),
                  _headerCell('Rate', align: pw.TextAlign.right),
                  _headerCell('Total', align: pw.TextAlign.right),
                ],
              ),
              for (final row in items)
                pw.TableRow(
                  children: [
                    _dataCell(row.date),
                    _dataCell(row.billNumber),
                    _dataCell(row.itemName),
                    _dataCell(row.category.isEmpty ? '-' : row.category),
                    _dataCell(row.quantity.toString(), align: pw.TextAlign.center),
                    _dataCell('Rs. ${row.rate.toStringAsFixed(2)}', align: pw.TextAlign.right),
                    _dataCell('Rs. ${row.subtotal.toStringAsFixed(2)}', align: pw.TextAlign.right),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    final fileName = 'item_detail_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await downloadPdf(await pdf.save(), fileName);
    return fileName;
  }

  static Future<String> exportItemSummaryReport({
    required List<PdfItemSummaryRow> summary,
    required String rangeLabel,
    required String shopName,
  }) async {
    final pdf = pw.Document();
    final totalQty = summary.fold(0, (sum, i) => sum + i.totalQty);
    final totalRev = summary.fold(0.0, (sum, i) => sum + i.totalRevenue);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(shopName, '$rangeLabel (Item Summary)'),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryCard('Unique Items Sold', summary.length.toString(), PdfColors.blue50),
              _summaryCard('Total Quantity Sold', totalQty.toString(), PdfColors.teal50),
              _summaryCard('Total Sales', 'Rs. ${totalRev.toStringAsFixed(2)}', PdfColors.green50),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _headerCell('Item Name'),
                  _headerCell('Category'),
                  _headerCell('Total Qty Sold', align: pw.TextAlign.center),
                  _headerCell('Total Revenue', align: pw.TextAlign.right),
                ],
              ),
              for (final row in summary)
                pw.TableRow(
                  children: [
                    _dataCell(row.itemName),
                    _dataCell(row.category.isEmpty ? '-' : row.category),
                    _dataCell(row.totalQty.toString(), align: pw.TextAlign.center),
                    _dataCell('Rs. ${row.totalRevenue.toStringAsFixed(2)}', align: pw.TextAlign.right),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    final fileName = 'item_summary_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await downloadPdf(await pdf.save(), fileName);
    return fileName;
  }

  static Future<String> exportCustomerDetailReport({
    required List<PdfCustomerDetailRow> customers,
    required String rangeLabel,
    required String shopName,
  }) async {
    final pdf = pw.Document();
    final totalRev = customers.fold(0.0, (sum, i) => sum + i.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(shopName, '$rangeLabel (Customer Details - Date Order)'),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryCard('Total Customer Orders', customers.length.toString(), PdfColors.blue50),
              _summaryCard('Total Revenue', 'Rs. ${totalRev.toStringAsFixed(2)}', PdfColors.green50),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2.5),
              2: pw.FlexColumnWidth(1.8),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(1.8),
              5: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _headerCell('Date/Time'),
                  _headerCell('Customer Name'),
                  _headerCell('Mobile'),
                  _headerCell('Bill No'),
                  _headerCell('Amount', align: pw.TextAlign.right),
                  _headerCell('Payment', align: pw.TextAlign.center),
                ],
              ),
              for (final row in customers)
                pw.TableRow(
                  children: [
                    _dataCell(row.date),
                    _dataCell(row.customerName.isEmpty ? 'Walk-in' : row.customerName),
                    _dataCell(row.customerPhone.isEmpty ? '-' : row.customerPhone),
                    _dataCell(row.billNumber),
                    _dataCell('Rs. ${row.amount.toStringAsFixed(2)}', align: pw.TextAlign.right),
                    _dataCell(row.paymentMode, align: pw.TextAlign.center),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    final fileName = 'customer_detail_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await downloadPdf(await pdf.save(), fileName);
    return fileName;
  }

  static Future<String> exportCustomerSummaryReport({
    required List<PdfCustomerSummaryRow> summary,
    required String rangeLabel,
    required String shopName,
  }) async {
    final pdf = pw.Document();
    final totalRev = summary.fold(0.0, (sum, i) => sum + i.totalSpent);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          _buildHeader(shopName, '$rangeLabel (Customer Summary)'),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _summaryCard('Total Customers', summary.length.toString(), PdfColors.blue50),
              _summaryCard('Total Revenue', 'Rs. ${totalRev.toStringAsFixed(2)}', PdfColors.green50),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(2),
              4: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  _headerCell('Customer Name'),
                  _headerCell('Mobile'),
                  _headerCell('Bills Count', align: pw.TextAlign.center),
                  _headerCell('Total Spent', align: pw.TextAlign.right),
                  _headerCell('Last Purchase'),
                ],
              ),
              for (final row in summary)
                pw.TableRow(
                  children: [
                    _dataCell(row.customerName.isEmpty ? 'Walk-in Customer' : row.customerName),
                    _dataCell(row.customerPhone.isEmpty ? '-' : row.customerPhone),
                    _dataCell(row.totalOrders.toString(), align: pw.TextAlign.center),
                    _dataCell('Rs. ${row.totalSpent.toStringAsFixed(2)}', align: pw.TextAlign.right),
                    _dataCell(row.lastPurchaseDate),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    final fileName = 'customer_summary_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await downloadPdf(await pdf.save(), fileName);
    return fileName;
  }
}

class PdfItemDetailRow {
  final String date;
  final String billNumber;
  final String itemName;
  final String category;
  final int quantity;
  final double rate;
  final double subtotal;

  PdfItemDetailRow({
    required this.date,
    required this.billNumber,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.rate,
    required this.subtotal,
  });
}

class PdfItemSummaryRow {
  final String itemName;
  final String category;
  final int totalQty;
  final double totalRevenue;

  PdfItemSummaryRow({
    required this.itemName,
    required this.category,
    required this.totalQty,
    required this.totalRevenue,
  });
}

class PdfCustomerDetailRow {
  final String date;
  final String customerName;
  final String customerPhone;
  final String billNumber;
  final double amount;
  final String paymentMode;
  final String status;

  PdfCustomerDetailRow({
    required this.date,
    required this.customerName,
    required this.customerPhone,
    required this.billNumber,
    required this.amount,
    required this.paymentMode,
    required this.status,
  });
}

class PdfCustomerSummaryRow {
  final String customerName;
  final String customerPhone;
  final int totalOrders;
  final double totalSpent;
  final String lastPurchaseDate;

  PdfCustomerSummaryRow({
    required this.customerName,
    required this.customerPhone,
    required this.totalOrders,
    required this.totalSpent,
    required this.lastPurchaseDate,
  });
}
