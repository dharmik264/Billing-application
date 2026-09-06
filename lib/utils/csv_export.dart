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
      ..writeln('Bill No,Token No,Customer Name,Customer Phone,Date & Time,Amount (INR),Payment Mode,Status,Order Type,Items');

    // Write Rows
    for (var token in tokens) {
      csvBuffer
        ..write('${escapeField(token.billNumber)},')
        ..write('${escapeField(token.tokenNumber)},')
        ..write('${escapeField(token.customerName)},')
        ..write('${escapeField(token.customerPhone)},')
        ..write('${escapeField(token.dateTime)},')
        ..write('${token.amount.toStringAsFixed(2)},')
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
}
