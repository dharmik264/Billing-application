import 'export.dart';
import 'pdf_export.dart'; // To reuse PdfTokenRow

class CsvExport {
  static Future<void> exportReport({
    required List<PdfTokenRow> tokens,
    required String rangeLabel,
    required String shopName,
    required double totalAmount,
  }) async {
    final StringBuffer csvBuffer = StringBuffer();

    // Utility to escape CSV fields
    String escapeField(String field) {
      if (field.contains(',') || field.contains('"') || field.contains('\n')) {
        return '"${field.replaceAll('"', '""')}"';
      }
      return field;
    }

    // Add Shop Name and Report Info
    csvBuffer
      ..writeln('Shop Name:,${escapeField(shopName)}')
      ..writeln('Report Range:,${escapeField(rangeLabel)}');
    
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    csvBuffer.writeln('Generated On:,${escapeField(dateStr)}');
    
    // Calculate Summaries
    int completedCount = tokens.where((t) => t.status.toLowerCase() == 'completed').length;
    int cancelledCount = tokens.where((t) => t.status.toLowerCase() == 'cancelled').length;
    double cashTotal = tokens
        .where((t) => t.payment.toLowerCase() == 'cash' && t.status.toLowerCase() != 'cancelled')
        .fold(0.0, (sum, t) => sum + t.amount);
    double onlineTotal = tokens
        .where((t) => t.payment.toLowerCase() != 'cash' && t.status.toLowerCase() != 'cancelled')
        .fold(0.0, (sum, t) => sum + t.amount);
    double realTotal = cashTotal + onlineTotal;

    csvBuffer
      ..writeln('Total Bills:,${tokens.length}')
      ..writeln('Completed Bills:,$completedCount')
      ..writeln('Cancelled Bills:,$cancelledCount')
      ..writeln('Total Amount (Before Cancellations):,${totalAmount.toStringAsFixed(2)}')
      ..writeln('Real Cash Collection:,${cashTotal.toStringAsFixed(2)}')
      ..writeln('Real Online Collection:,${onlineTotal.toStringAsFixed(2)}')
      ..writeln('Real Total Collection:,${realTotal.toStringAsFixed(2)}')
      ..writeln('') // Empty line
      ..writeln('') // Empty line
      ..writeln('Bill No,Token No,Customer Name,Customer Phone,Date & Time,Subtotal (INR),GST (INR),Final Amount (INR),Payment Mode,Status,Order Type,Items');

    // Write Rows
    for (var token in tokens) {
      csvBuffer
        ..write('${escapeField(token.billNumber)},')
        ..write('${escapeField(token.tokenNumber)},')
        ..write('${escapeField(token.customerName)},')
        ..write('${escapeField(token.customerPhone)},')
        ..write('${escapeField(token.dateTime)},')
        ..write('${token.subtotal.toStringAsFixed(2)},')
        ..write('${token.gstAmount.toStringAsFixed(2)},')
        ..write('${token.finalAmount.toStringAsFixed(2)},')
        ..write('${escapeField(token.payment)},')
        ..write('${escapeField(token.status)},')
        ..write('${escapeField(token.orderType)},')
        ..write('${escapeField(token.items)}\n');
    }

    final fileDateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rangeSafe = rangeLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final fileName = 'report_${rangeSafe}_$fileDateStr.csv';

    await downloadCsv(csvBuffer.toString(), fileName);
  }

  static Future<void> exportCustomerLedgerReport({
    required String customerName,
    required String customerPhone,
    required List<PdfCustomerLedgerRow> ledgerRows,
    required String rangeLabel,
    required String shopName,
    required double totalDebit,
    required double totalCredit,
    required double netBalance,
  }) async {
    final StringBuffer csvBuffer = StringBuffer();

    String escapeField(String field) {
      if (field.contains(',') || field.contains('"') || field.contains('\n')) {
        return '"${field.replaceAll('"', '""')}"';
      }
      return field;
    }

    csvBuffer
      ..writeln('Shop Name:,${escapeField(shopName)}')
      ..writeln('Report Type:,Customer Ledger Statement')
      ..writeln('Customer Name:,${escapeField(customerName.isEmpty ? "Walk-in Customer" : customerName)}')
      ..writeln('Customer Phone:,${escapeField(customerPhone.isEmpty ? "N/A" : customerPhone)}')
      ..writeln('Report Range:,${escapeField(rangeLabel)}');

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    csvBuffer.writeln('Generated On:,${escapeField(dateStr)}');

    csvBuffer
      ..writeln('Total Billed (Debit):,${totalDebit.toStringAsFixed(2)}')
      ..writeln('Total Received (Credit):,${totalCredit.toStringAsFixed(2)}')
      ..writeln('Net Outstanding Balance:,${netBalance.toStringAsFixed(2)}')
      ..writeln('')
      ..writeln('Date & Time,Bill No,Particulars,Debit (+),Credit (-),Running Balance,Payment Mode,Status');

    for (var row in ledgerRows) {
      csvBuffer
        ..write('${escapeField(row.date)},')
        ..write('${escapeField(row.billNumber)},')
        ..write('${escapeField(row.particulars)},')
        ..write('${row.debit > 0 ? row.debit.toStringAsFixed(2) : "0.00"},')
        ..write('${row.credit > 0 ? row.credit.toStringAsFixed(2) : "0.00"},')
        ..write('${row.runningBalance.toStringAsFixed(2)},')
        ..write('${escapeField(row.paymentMode)},')
        ..write('${escapeField(row.status)}\n');
    }

    final safeName = customerName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
    final fileName = 'customer_ledger_${safeName.isEmpty ? "walkin" : safeName}_${DateTime.now().millisecondsSinceEpoch}.csv';

    await downloadCsv(csvBuffer.toString(), fileName);
  }
}

