import re

with open('lib/widgets/bill_receipt_widget.dart', 'r', encoding='utf-8') as f:
    bw = f.read()

bw = bw.replace('style: const TextStyle(\n                fontSize: isForPrint ? 18', 'style: TextStyle(\n                fontSize: isForPrint ? 18')
bw = bw.replace('style: const TextStyle(\n                fontSize: isForPrint ? 15', 'style: TextStyle(\n                fontSize: isForPrint ? 15')

# Check other const TextStyles that were replaced:
bw = bw.replace('style: const TextStyle(fontSize: isForPrint', 'style: TextStyle(fontSize: isForPrint')

# Also check Text('ITEM', style: const TextStyle(
bw = bw.replace('const TextStyle(fontSize: isForPrint', 'TextStyle(fontSize: isForPrint')

with open('lib/widgets/bill_receipt_widget.dart', 'w', encoding='utf-8') as f:
    f.write(bw)
