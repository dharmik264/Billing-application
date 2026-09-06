import fitz
import sys

try:
    doc = fitz.open('sample_a4_bill.pdf')
    page = doc.load_page(0)
    pix = page.get_pixmap(dpi=150)
    pix.save(r'C:\Users\dp982\.gemini\antigravity-ide\brain\a7b17cee-6c2a-4ad0-89a6-558427ff58d4\sample_a4_bill.png')
    print("SUCCESS")
except Exception as e:
    print("ERROR:", str(e))
    sys.exit(1)
