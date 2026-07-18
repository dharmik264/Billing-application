import re

with open('lib/widgets/bill_receipt_widget.dart', 'r', encoding='utf-8') as f:
    bw = f.read()

bw = bw.replace('const Text(', 'Text(')

with open('lib/widgets/bill_receipt_widget.dart', 'w', encoding='utf-8') as f:
    f.write(bw)
