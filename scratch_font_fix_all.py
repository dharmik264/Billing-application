import re

with open('lib/widgets/bill_receipt_widget.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Replace fontSize: X,
def replace_fontsize(match):
    val = int(match.group(1))
    # Don't replace if it's already a ternary
    return f'fontSize: isForPrint ? {int(val * 2.2)} : {val},'

# The regex matches fontSize: \d+, but we must avoid matching already modified ones.
# Actually, since I removed consts earlier, they just look like ontSize: 12, or ontSize: 10,
# But wait, in dart, they might not have a comma immediately after, e.g. ontSize: 10
def replace_fontsize_all(match):
    val = int(match.group(1))
    return f'fontSize: isForPrint ? {int(val * 2.2)} : {val}'

text = re.sub(r'fontSize:\s*(\d+)', replace_fontsize_all, text)

# Now fix the size: X in _receiptTotalRow calls
def replace_size_arg(match):
    val = int(match.group(1))
    return f'size: isForPrint ? {int(val * 2.2)} : {val}'

text = re.sub(r'size:\s*(\d+)\)', replace_size_arg, text)
text = re.sub(r'size:\s*(\d+),', lambda m: f'size: isForPrint ? {int(int(m.group(1)) * 2.2)} : {m.group(1)},', text)

with open('lib/widgets/bill_receipt_widget.dart', 'w', encoding='utf-8') as f:
    f.write(text)
