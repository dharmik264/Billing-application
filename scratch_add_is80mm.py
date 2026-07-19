import re

# 1. Add get is80mm to PrinterService
with open('lib/services/printer_service.dart', 'r', encoding='utf-8') as f:
    ps = f.read()

if 'bool get is80mm' not in ps:
    ps = ps.replace('PaperSize _paperSize = PaperSize.mm58;', 'PaperSize _paperSize = PaperSize.mm58;\n  bool get is80mm => _paperSize == PaperSize.mm80;')
    with open('lib/services/printer_service.dart', 'w', encoding='utf-8') as f:
        f.write(ps)

# 2. Update BillReceiptWidget constructor to take is80mm
with open('lib/widgets/bill_receipt_widget.dart', 'r', encoding='utf-8') as f:
    bw = f.read()

if 'final bool is80mm;' not in bw:
    bw = bw.replace('this.isForPrint = false,\n  })', 'this.isForPrint = false,\n    this.is80mm = false,\n  })')
    bw = bw.replace('final bool isForPrint;', 'final bool isForPrint;\n  final bool is80mm;')
    
    bw = bw.replace('width: isForPrint ? 340 : double.infinity,', 'width: isForPrint ? (is80mm ? 510 : 340) : double.infinity,')
    with open('lib/widgets/bill_receipt_widget.dart', 'w', encoding='utf-8') as f:
        f.write(bw)

# 3. Update PrintPreviewScreen to pass is80mm
with open('lib/screens/print_preview_screen.dart', 'r', encoding='utf-8') as f:
    pp = f.read()

if 'is80mm: PrinterService.instance.is80mm,' not in pp:
    pp = pp.replace('isForPrint: _isCapturingForPrint,\n    ));', 'isForPrint: _isCapturingForPrint,\n      is80mm: PrinterService.instance.is80mm,\n    ));')
    with open('lib/screens/print_preview_screen.dart', 'w', encoding='utf-8') as f:
        f.write(pp)

