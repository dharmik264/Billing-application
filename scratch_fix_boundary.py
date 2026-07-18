import re

with open('lib/screens/print_preview_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("qrBytesOverride: _qrBytes,\n      );", "qrBytesOverride: _qrBytes,\n      ));")

with open('lib/screens/print_preview_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
