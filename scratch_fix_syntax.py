import re

with open('lib/widgets/bill_receipt_widget.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("size: isForPrint ? 24 : 11,\n", "size: isForPrint ? 24 : 11),\n")
text = text.replace("size: isForPrint ? 24 : 11;", "size: isForPrint ? 24 : 11);")
text = text.replace("size: isForPrint ? 28 : 13,\n", "size: isForPrint ? 28 : 13),\n")

with open('lib/widgets/bill_receipt_widget.dart', 'w', encoding='utf-8') as f:
    f.write(text)
