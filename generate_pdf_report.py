import os
import re
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable, KeepTogether
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 9)
        self.setFillColor(colors.HexColor("#64748B"))
        
        # Header (pages 2+)
        if self._pageNumber > 1:
            self.drawString(36, 560, "Dhara Food POS — Data Storage Audit Report")
            self.setStrokeColor(colors.HexColor("#E2E8F0"))
            self.setLineWidth(0.5)
            self.line(36, 552, 806, 552)

        # Footer (all pages)
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(806, 25, page_str)
        self.drawString(36, 25, "Confidential & Proprietary — Dhara Food POS Audit")
        self.setStrokeColor(colors.HexColor("#E2E8F0"))
        self.setLineWidth(0.5)
        self.line(36, 38, 806, 38)
        
        self.restoreState()


def create_pdf_report(md_path, pdf_path):
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=landscape(A4),
        leftMargin=36,
        rightMargin=36,
        topMargin=48,
        bottomMargin=48
    )

    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=24,
        textColor=colors.HexColor('#0F172A'),
        spaceAfter=6
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubTitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10,
        leading=14,
        textColor=colors.HexColor('#475569'),
        spaceAfter=14
    )
    
    h2_style = ParagraphStyle(
        'SectionH2',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=17,
        textColor=colors.HexColor('#1E293B'),
        spaceBefore=12,
        spaceAfter=6
    )

    body_style = ParagraphStyle(
        'BodyTextCustom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=colors.HexColor('#334155'),
        spaceAfter=6
    )

    bullet_style = ParagraphStyle(
        'BulletCustom',
        parent=body_style,
        leftIndent=15,
        firstLineIndent=-10,
        spaceAfter=4
    )

    th_style = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=9,
        leading=11,
        textColor=colors.white
    )

    tb_style = ParagraphStyle(
        'TableBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=11.5,
        textColor=colors.HexColor('#1E293B')
    )

    tb_bold_style = ParagraphStyle(
        'TableBodyBold',
        parent=tb_style,
        fontName='Helvetica-Bold'
    )

    story = []

    with open(md_path, 'r', encoding='utf-8') as f:
        md_text = f.read()

    lines = md_text.splitlines()
    in_table = False
    table_rows = []

    for line in lines:
        line_str = line.strip()

        # Handle Markdown Table
        if line_str.startswith('|') and line_str.endswith('|'):
            in_table = True
            # Check if divider line like |---|---|
            if re.match(r'^\|[\s\-:|]+\|$', line_str):
                continue
            cells = [c.strip() for c in line_str.split('|')[1:-1]]
            table_rows.append(cells)
            continue
        elif in_table:
            # End of table block, render table
            if table_rows:
                story.append(render_table(table_rows, th_style, tb_style, tb_bold_style))
                story.append(Spacer(1, 10))
                table_rows = []
            in_table = False

        if not line_str:
            continue

        if line_str.startswith('# '):
            title_text = line_str[2:].strip()
            story.append(Paragraph(title_text, title_style))
            story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor('#4F46E5'), spaceAfter=10))
        elif line_str.startswith('**Application Name:**'):
            story.append(Paragraph(format_inline_markdown(line_str), subtitle_style))
        elif line_str.startswith('## '):
            h2_text = line_str[3:].strip()
            story.append(Paragraph(h2_text, h2_style))
            story.append(HRFlowable(width="100%", thickness=0.8, color=colors.HexColor('#CBD5E1'), spaceAfter=6))
        elif line_str.startswith('---'):
            continue
        elif re.match(r'^\d+\.\s', line_str):
            # Numbered list
            text = re.sub(r'^\d+\.\s', '', line_str)
            text = format_inline_markdown(text)
            story.append(Paragraph(f"• {text}", bullet_style))
        elif line_str.startswith('- '):
            text = line_str[2:].strip()
            text = format_inline_markdown(text)
            story.append(Paragraph(f"• {text}", bullet_style))
        else:
            text = format_inline_markdown(line_str)
            story.append(Paragraph(text, body_style))

    # Catch any remaining table at the end
    if in_table and table_rows:
        story.append(render_table(table_rows, th_style, tb_style, tb_bold_style))

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Successfully generated PDF report: {pdf_path}")


def format_inline_markdown(text):
    text = re.sub(r'\*\*(.*?)\*\*', r'<b>\1</b>', text)
    text = re.sub(r'`(.*?)`', r'<font face="Courier" color="#1E293B"><b>\1</b></font>', text)
    text = text.replace('<br>', '<br/>')
    return text


def render_table(rows, th_style, tb_style, tb_bold_style):
    data = []
    for row_idx, row in enumerate(rows):
        formatted_row = []
        for cell in row:
            text = format_inline_markdown(cell)
            if row_idx == 0:
                p = Paragraph(text, th_style)
            else:
                if 'VERIFIED' in text or 'FIXED' in text:
                    text = text.replace('VERIFIED', '<font color="#059669"><b>VERIFIED</b></font>')
                    text = text.replace('FIXED', '<font color="#2563EB"><b>FIXED</b></font>')
                p = Paragraph(text, tb_style)
            formatted_row.append(p)
        data.append(formatted_row)

    # Column widths for Landscape A4 (total width ~770 pt)
    col_widths = [120, 110, 110, 130, 110, 190]

    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1E293B')),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F8FAFC')]),
    ]))
    return t

if __name__ == '__main__':
    md_file = r"d:\DharmikProject\billing application\DATA_STORAGE_AUDIT_REPORT.md"
    pdf_file = r"d:\DharmikProject\billing application\DATA_STORAGE_AUDIT_REPORT.pdf"
    create_pdf_report(md_file, pdf_file)
