"""
invoices/tasks.py
"""
from celery import shared_task
from django.core.mail import EmailMessage
from django.conf import settings


@shared_task(name='invoices.send_invoice_email')
def send_invoice_email(invoice_id):
    from .models import Invoice
    from .pdf_service import generate_invoice_pdf
    invoice = Invoice.objects.get(id=invoice_id)
    pdf     = generate_invoice_pdf(invoice)
    email   = EmailMessage(
        subject=f'Invoice #{invoice.invoice_number} from {invoice.organisation.name}',
        body=f'Please find your invoice attached. Total due: {invoice.currency} {invoice.total}',
        from_email=settings.DEFAULT_FROM_EMAIL,
        to=[invoice.bill_to_email],
    )
    email.attach(f'invoice-{invoice.invoice_number}.pdf', pdf, 'application/pdf')
    email.send()


@shared_task(name='invoices.send_overdue_reminders')
def send_overdue_reminders():
    """Called periodically via Celery Beat."""
    from django.utils import timezone
    from .models import Invoice
    overdue = Invoice.objects.filter(
        status=Invoice.Status.OPEN,
        due_date__lt=timezone.now().date(),
    )
    for invoice in overdue:
        invoice.status = Invoice.Status.PAST_DUE
        invoice.save()
        send_invoice_email.delay(str(invoice.id))
