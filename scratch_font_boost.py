import re

with open('lib/widgets/bill_receipt_widget.dart', 'r', encoding='utf-8') as f:
    bw = f.read()

# Make the print container 340px instead of 400px to force content to scale up more when stretched to fit paper
bw = bw.replace('width: isForPrint ? 400 : double.infinity,', 'width: isForPrint ? 340 : double.infinity,')

# Boost font sizes aggressively
bw = bw.replace('isForPrint ? 12 : 10', 'isForPrint ? 16 : 10')
bw = bw.replace('isForPrint ? 18 : 13', 'isForPrint ? 26 : 13')
bw = bw.replace('isForPrint ? 15 : 11', 'isForPrint ? 20 : 11')
bw = bw.replace('isForPrint ? 12 : 9', 'isForPrint ? 15 : 9')
bw = bw.replace('isForPrint ? 16 : 12', 'isForPrint ? 22 : 12')
bw = bw.replace('isForPrint ? 18 : 14', 'isForPrint ? 26 : 14')

# Ensure color is black for max contrast in print
bw = bw.replace('color: textSecondary', 'color: isForPrint ? Colors.black : textSecondary')
bw = bw.replace('color: textPrimary', 'color: isForPrint ? Colors.black : textPrimary')
bw = bw.replace('color: muted', 'color: isForPrint ? Colors.black : muted')

with open('lib/widgets/bill_receipt_widget.dart', 'w', encoding='utf-8') as f:
    f.write(bw)
