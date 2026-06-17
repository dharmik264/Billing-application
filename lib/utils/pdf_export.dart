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
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
                style: pw.TextStyle(
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
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
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
                  style: pw.TextStyle(
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
                  style: pw.TextStyle(
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
        0: pw.FlexColumnWidth(1.5),
        1: pw.FlexColumnWidth(1.5),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(2.5),
        4: pw.FlexColumnWidth(2.5),
        5: pw.FlexColumnWidth(2.5), // Items
        6: pw.FlexColumnWidth(1.5), // Amount
        7: pw.FlexColumnWidth(1.5), // Payment
        8: pw.FlexColumnWidth(1.5), // Status
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
        style: pw.TextStyle(
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
}
