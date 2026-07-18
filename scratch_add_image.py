import re

with open('lib/services/printer_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Make sure image import is present
if "import 'package:image/image.dart'" not in content:
    content = content.replace("import 'package:blue_thermal_printer/blue_thermal_printer.dart';", "import 'package:blue_thermal_printer/blue_thermal_printer.dart';\nimport 'package:image/image.dart' as img;")

image_method = '''
  Future<void> printReceiptImage(Uint8List pngBytes) async {
    final connected = await isConnected;
    if (!connected) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(_paperSize, profile);
    List<int> bytes = [];

    final decodedImage = img.decodeImage(pngBytes);
    if (decodedImage != null) {
      bytes += generator.imageRaster(decodedImage);
    }
    
    bytes += generator.feed(2);
    bytes += generator.cut();

    await writeBytes(bytes);
  }

  Future<void> printReceipt('''

content = content.replace('  Future<void> printReceipt(', image_method)

with open('lib/services/printer_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
