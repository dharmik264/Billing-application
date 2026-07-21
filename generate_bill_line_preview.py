from pathlib import Path
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    import subprocess
    import sys
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'Pillow'])
    from PIL import Image, ImageDraw, ImageFont

text = 'ABCDEFGHIJKLMNOPQRST'
font_size = 24
try:
    font = ImageFont.truetype('arial.ttf', font_size)
except Exception:
    font = ImageFont.load_default()

padding = 16
img_dummy = Image.new('RGB', (1, 1), 'white')
draw = ImageDraw.Draw(img_dummy)
w, h = draw.textsize(text, font=font)
img = Image.new('RGB', (w + padding * 2, h + padding * 2), 'white')
draw = ImageDraw.Draw(img)
draw.text((padding, padding), text, fill='black', font=font)
path = Path('bill_line_20_chars_preview.png')
img.save(path)
print(path.resolve())
