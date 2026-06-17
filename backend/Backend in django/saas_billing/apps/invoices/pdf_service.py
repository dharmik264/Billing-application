"""
invoices/pdf_service.py
PDF generation using ReportLab.
"""
from io import BytesIO
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_RIGHT, TA_CENTER


def generate_invoice_pdf(invoice):
    buffer = BytesIO()
    doc    = SimpleDocTemplate(buffer, pagesize=A4, topMargin=2*cm, bottomMargin=2*cm)
    styles = getSampleStyleSheet()
    story  = []

    # Header
    title_style = ParagraphStyle('title', fontSize=24, spaceAfter=12, textColor=colors.HexColor('#1a1a2e'))
    story.append(Paragraph('INVOICE', title_style))
    story.append(Paragraph(f'Invoice #: {invoice.invoice_number}', styles['Normal']))
    story.append(Paragraph(f'Date: {invoice.issue_date}', styles['Normal']))
    story.append(Paragraph(f'Due: {invoice.due_date}', styles['Normal']))
    story.append(Spacer(1, 0.5*cm))

    # Bill To
    story.append(Paragraph('<b>Bill To:</b>', styles['Normal']))
    story.append(Paragraph(invoice.bill_to_name, styles['Normal']))
    story.append(Paragraph(invoice.bill_to_email, styles['Normal']))
    if invoice.bill_to_address:
        story.append(Paragraph(invoice.bill_to_address, styles['Normal']))
    story.append(Spacer(1, 0.5*cm))

    # Line Items Table
    data = [['Description', 'Qty', 'Unit Price', 'Tax', 'Total']]
    for item in invoice.line_items.all():
        data.append([
            item.description,
            str(item.quantity),
            f'{invoice.currency} {item.unit_price:.2f}',
            f'{item.tax_rate.rate}%' if item.tax_rate else '0%',
            f'{invoice.currency} {item.line_total:.2f}',
        ])

    table = Table(data, colWidths=[8*cm, 2*cm, 3*cm, 2*cm, 3*cm])
    table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1a1a2e')),
        ('TEXTCOLOR',  (0,0), (-1,0), colors.white),
        ('FONTNAME',   (0,0), (-1,0), 'Helvetica-Bold'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#f5f5f5')]),
        ('GRID',       (0,0), (-1,-1), 0.5, colors.HexColor('#dddddd')),
        ('ALIGN',      (1,0), (-1,-1), 'RIGHT'),
        ('PADDING',    (0,0), (-1,-1), 6),
    ]))
    story.append(table)
    story.append(Spacer(1, 0.5*cm))

    # Totals
    totals = [
        ['Subtotal', f'{invoice.currency} {invoice.subtotal:.2f}'],
        ['Tax',      f'{invoice.currency} {invoice.tax_amount:.2f}'],
        ['Discount', f'- {invoice.currency} {invoice.discount_amount:.2f}'],
        ['TOTAL',    f'{invoice.currency} {invoice.total:.2f}'],
    ]
    totals_table = Table(totals, colWidths=[14*cm, 4*cm])
    totals_table.setStyle(TableStyle([
        ('ALIGN',     (1,0), (1,-1), 'RIGHT'),
        ('FONTNAME',  (0,-1), (-1,-1), 'Helvetica-Bold'),
        ('FONTSIZE',  (0,-1), (-1,-1), 12),
        ('LINEABOVE', (0,-1), (-1,-1), 1, colors.black),
    ]))
    story.append(totals_table)

    if invoice.notes:
        story.append(Spacer(1, 1*cm))
        story.append(Paragraph(f'<b>Notes:</b> {invoice.notes}', styles['Normal']))

    doc.build(story)
    return buffer.getvalue()
