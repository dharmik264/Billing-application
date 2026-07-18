import re

with open('lib/screens/print_preview_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add dart:ui import
if "import 'dart:ui' as ui;" not in content:
    content = content.replace("import 'dart:typed_data';", "import 'dart:typed_data';\nimport 'dart:ui' as ui;\nimport 'package:flutter/rendering.dart';")

# 2. Add GlobalKey
if "final GlobalKey _receiptKey = GlobalKey();" not in content:
    content = content.replace("bool _printKitchenSlip = true;", "bool _printKitchenSlip = true;\n  final GlobalKey _receiptKey = GlobalKey();")

# 3. Wrap _buildReceipt with RepaintBoundary
content = content.replace("return BillReceiptWidget(", "return RepaintBoundary(\n        key: _receiptKey,\n        child: BillReceiptWidget(")

# 4. In _executePrint, capture the image and call printReceiptImage
old_execute = '''      if (_printCustomerSlip) {
        await PrinterService.instance.printReceipt(tokenToPrint, finalShop, finalTemplate);
      }'''

new_execute = '''      if (_printCustomerSlip) {
        try {
          RenderRepaintBoundary? boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          if (boundary != null) {
            ui.Image image = await boundary.toImage(pixelRatio: 2.0);
            ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            if (byteData != null) {
              Uint8List pngBytes = byteData.buffer.asUint8List();
              await PrinterService.instance.printReceiptImage(pngBytes);
            } else {
              await PrinterService.instance.printReceipt(tokenToPrint, finalShop, finalTemplate);
            }
          } else {
            await PrinterService.instance.printReceipt(tokenToPrint, finalShop, finalTemplate);
          }
        } catch (e) {
          await PrinterService.instance.printReceipt(tokenToPrint, finalShop, finalTemplate);
        }
      }'''

content = content.replace(old_execute, new_execute)

with open('lib/screens/print_preview_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
