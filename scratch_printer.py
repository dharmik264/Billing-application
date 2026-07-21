import os
from PIL import Image, ImageDraw, ImageFont

img = Image.new('RGB', (420, 850), color='#F9F9F9')
d = ImageDraw.Draw(img)

try:
    font = ImageFont.truetype("consola.ttf", 32)
    font_large = ImageFont.truetype("consola.ttf", 72)
    font_bold = ImageFont.truetype("consolab.ttf", 32)
except:
    font = ImageFont.load_default()
    font_large = font
    font_bold = font

# Custom drawing to simulate Size 5 (very large) and Size 2 (normal large)
y = 20
def draw_line(text, size=2, align='left'):
    global y
    f = font_large if size == 5 else font
    # approximate width
    w = d.textlength(text, font=f)
    if align == 'center':
        x = (420 - w) / 2
    else:
        x = 25
    d.text((x, y), text, fill='black', font=f)
    y += 80 if size == 5 else 34

draw_line("RESTAURANT", size=5, align='center')
draw_line("TAX INVOICE", size=2, align='center')
draw_line("--------------------", size=2)
draw_line("Inv: 101", size=2)
draw_line("TOKEN", size=2, align='center')
draw_line("55", size=5, align='center')
draw_line("Date: 2026-07-21", size=2)
draw_line("--------------------", size=2)
draw_line("       ITEMS        ", size=2)
draw_line("--------------------", size=2)
draw_line("PANEER TIKKA", size=2)
draw_line("2 x 150       300.00", size=2)
draw_line("BUTTER NAAN", size=2)
draw_line("4 x 30        120.00", size=2)
draw_line("--------------------", size=2)
draw_line("Subtotal:     420.00", size=2)
draw_line("Tax:           21.00", size=2)
draw_line("====================", size=2)
draw_line("GRAND TOTAL", size=2, align='center')
draw_line("441.00", size=5, align='center')
draw_line("====================", size=2)
draw_line("Pay Mode:       CASH", size=2)

out = r'C:\Users\dp982\.gemini\antigravity\brain\d9ee047e-5e16-46be-9d95-6058d57e891b\scratch\bill_render_size5.png'
os.makedirs(os.path.dirname(out), exist_ok=True)
img.save(out)
print(out)
