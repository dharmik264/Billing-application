import re

with open('lib/widgets/bill_receipt_widget.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('style: const TextStyle(', 'style: TextStyle(')

with open('lib/widgets/bill_receipt_widget.dart', 'w', encoding='utf-8') as f:
    f.write(text)
