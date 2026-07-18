import re

# Update BillReceiptWidget
with open('lib/widgets/bill_receipt_widget.dart', 'r', encoding='utf-8') as f:
    bw = f.read()

bw = bw.replace('this.qrBytesOverride,\n  })', 'this.qrBytesOverride,\n    this.isForPrint = false,\n  })')
bw = bw.replace('final Uint8List? qrBytesOverride;', 'final Uint8List? qrBytesOverride;\n  final bool isForPrint;')

# Base style scaling
bw = bw.replace('const baseStyle = TextStyle(fontSize: 10, color: textSecondary);', 'final baseStyle = TextStyle(fontSize: isForPrint ? 12 : 10, color: textSecondary, fontWeight: isForPrint ? FontWeight.bold : FontWeight.normal);')

# Update Container padding and width
container_old = '''    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),'''
container_new = '''    return Container(
      width: isForPrint ? 400 : double.infinity,
      padding: isForPrint ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8) : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isForPrint ? 0 : 14),
        border: isForPrint ? null : Border.all(color: border, width: 0.5),
      ),'''
bw = bw.replace(container_old, container_new)

# Increase fonts for print
bw = bw.replace('fontSize: 13,\n                fontWeight: FontWeight.w700,', 'fontSize: isForPrint ? 18 : 13,\n                fontWeight: FontWeight.w900,')
bw = bw.replace('fontSize: 11,\n                fontWeight: FontWeight.w600,', 'fontSize: isForPrint ? 15 : 11,\n                fontWeight: FontWeight.w800,')

# Headers
bw = bw.replace("Text('ITEM', style: TextStyle(fontSize: 9", "Text('ITEM', style: TextStyle(fontSize: isForPrint ? 12 : 9")
bw = bw.replace("Text('QTY', style: TextStyle(fontSize: 9", "Text('QTY', style: TextStyle(fontSize: isForPrint ? 12 : 9")
bw = bw.replace("Text('RATE', style: TextStyle(fontSize: 9", "Text('RATE', style: TextStyle(fontSize: isForPrint ? 12 : 9")
bw = bw.replace("Text('TOTAL', style: TextStyle(fontSize: 9", "Text('TOTAL', style: TextStyle(fontSize: isForPrint ? 12 : 9")

# Item rows
bw = bw.replace("Text(\n                                i.name,\n                                style: const TextStyle(", "Text(\n                                i.name,\n                                style: TextStyle(\n                                  fontSize: isForPrint ? 12 : 10, fontWeight: isForPrint ? FontWeight.bold : FontWeight.normal,")
bw = bw.replace("Text(\n                                '',\n                                textAlign: TextAlign.center,\n                                style: const TextStyle(", "Text(\n                                '',\n                                textAlign: TextAlign.center,\n                                style: TextStyle(\n                                  fontSize: isForPrint ? 12 : 10, fontWeight: isForPrint ? FontWeight.bold : FontWeight.normal,")
bw = bw.replace("Text(\n                                i.rate.toStringAsFixed(2),\n                                textAlign: TextAlign.right,\n                                style: const TextStyle(", "Text(\n                                i.rate.toStringAsFixed(2),\n                                textAlign: TextAlign.right,\n                                style: TextStyle(\n                                  fontSize: isForPrint ? 12 : 10, fontWeight: isForPrint ? FontWeight.bold : FontWeight.normal,")
bw = bw.replace("Text(\n                                _money(i.subtotal),\n                                textAlign: TextAlign.right,\n                                style: const TextStyle(", "Text(\n                                _money(i.subtotal),\n                                textAlign: TextAlign.right,\n                                style: TextStyle(\n                                  fontSize: isForPrint ? 12 : 10, fontWeight: isForPrint ? FontWeight.bold : FontWeight.normal,")

# Totals
bw = bw.replace("Text('Subtotal', style: TextStyle(fontSize: 10", "Text('Subtotal', style: TextStyle(fontSize: isForPrint ? 12 : 10")
bw = bw.replace("Text(_money(subtotal), style: const TextStyle(fontSize: 10", "Text(_money(subtotal), style: TextStyle(fontSize: isForPrint ? 12 : 10")
bw = bw.replace("Text('Tax', style: TextStyle(fontSize: 10", "Text('Tax', style: TextStyle(fontSize: isForPrint ? 12 : 10")
bw = bw.replace("Text(_money(tax), style: const TextStyle(fontSize: 10", "Text(_money(tax), style: TextStyle(fontSize: isForPrint ? 12 : 10")
bw = bw.replace("Text('Grand Total', style: TextStyle(fontSize: 12", "Text('Grand Total', style: TextStyle(fontSize: isForPrint ? 16 : 12")
bw = bw.replace("Text(_money(grandTotal), style: const TextStyle(fontSize: 14", "Text(_money(grandTotal), style: TextStyle(fontSize: isForPrint ? 18 : 14")

with open('lib/widgets/bill_receipt_widget.dart', 'w', encoding='utf-8') as f:
    f.write(bw)


# Update Print Preview Screen
with open('lib/screens/print_preview_screen.dart', 'r', encoding='utf-8') as f:
    pp = f.read()

if 'bool _isCapturingForPrint = false;' not in pp:
    pp = pp.replace('bool _isPrinting = false;', 'bool _isPrinting = false;\n  bool _isCapturingForPrint = false;')

pp = pp.replace('qrBytesOverride: _qrBytes,\n    ));', 'qrBytesOverride: _qrBytes,\n      isForPrint: _isCapturingForPrint,\n    ));')

old_execute = '''    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {'''
new_execute = '''    if (_isPrinting) return;
    setState(() {
      _isPrinting = true;
      _isCapturingForPrint = true;
    });
    
    // Wait for the UI to re-render without padding and scaled up
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {'''

pp = pp.replace(old_execute, new_execute)

old_finally = '''    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }'''
new_finally = '''    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
          _isCapturingForPrint = false;
        });
      }
    }'''
    
pp = pp.replace(old_finally, new_finally)

with open('lib/screens/print_preview_screen.dart', 'w', encoding='utf-8') as f:
    f.write(pp)

