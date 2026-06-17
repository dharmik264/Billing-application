"""
invoices/models.py
Invoice, LineItem, Tax models
"""
import uuid
from django.db import models
from django.utils import timezone
from apps.accounts.models import Organisation, User


class TaxRate(models.Model):
    name        = models.CharField(max_length=100)  # e.g. 'GST', 'VAT'
    rate        = models.DecimalField(max_digits=5, decimal_places=2)  # e.g. 18.00 for 18%
    country     = models.CharField(max_length=2, blank=True)
    is_active   = models.BooleanField(default=True)
    description = models.CharField(max_length=255, blank=True)

    def __str__(self):
        return f'{self.name} ({self.rate}%)'


class Invoice(models.Model):
    class Status(models.TextChoices):
        DRAFT    = 'draft',    'Draft'
        OPEN     = 'open',     'Open'
        PAID     = 'paid',     'Paid'
        VOID     = 'void',     'Void'
        PAST_DUE = 'past_due', 'Past Due'
        REFUNDED = 'refunded', 'Refunded'

    class Currency(models.TextChoices):
        USD = 'USD', 'US Dollar'
        EUR = 'EUR', 'Euro'
        GBP = 'GBP', 'British Pound'
        INR = 'INR', 'Indian Rupee'

    id              = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    invoice_number  = models.CharField(max_length=50, unique=True)
    organisation    = models.ForeignKey(Organisation, on_delete=models.CASCADE, related_name='invoices')
    created_by      = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='created_invoices')

    status          = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    currency        = models.CharField(max_length=3, choices=Currency.choices, default=Currency.USD)

    # Recipient
    bill_to_name    = models.CharField(max_length=200)
    bill_to_email   = models.EmailField()
    bill_to_address = models.TextField(blank=True)
    bill_to_tax_id  = models.CharField(max_length=50, blank=True)

    # Dates
    issue_date      = models.DateField(default=timezone.now)
    due_date        = models.DateField()
    paid_at         = models.DateTimeField(null=True, blank=True)

    # Amounts (calculated from line items)
    subtotal        = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    tax_amount      = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    discount_amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total           = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    amount_paid     = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    amount_due      = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    # Stripe
    stripe_invoice_id = models.CharField(max_length=100, blank=True)

    notes           = models.TextField(blank=True)
    footer          = models.TextField(blank=True)
    pdf_url         = models.URLField(blank=True)

    created_at      = models.DateTimeField(auto_now_add=True)
    updated_at      = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Invoice #{self.invoice_number} — {self.organisation.name}'

    def calculate_totals(self):
        """Recalculate totals from line items."""
        subtotal = sum(item.line_total for item in self.line_items.all())
        tax      = sum(item.tax_amount  for item in self.line_items.all())
        self.subtotal   = subtotal
        self.tax_amount = tax
        self.total      = subtotal + tax - self.discount_amount
        self.amount_due = self.total - self.amount_paid
        self.save()


class LineItem(models.Model):
    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    invoice     = models.ForeignKey(Invoice, on_delete=models.CASCADE, related_name='line_items')
    description = models.CharField(max_length=500)
    quantity    = models.DecimalField(max_digits=10, decimal_places=2, default=1)
    unit_price  = models.DecimalField(max_digits=12, decimal_places=2)
    tax_rate    = models.ForeignKey(TaxRate, on_delete=models.SET_NULL, null=True, blank=True)
    discount_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    sort_order  = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['sort_order']

    def __str__(self):
        return f'{self.description} × {self.quantity}'

    @property
    def line_total_before_tax(self):
        base = self.quantity * self.unit_price
        return base * (1 - self.discount_percent / 100)

    @property
    def tax_amount(self):
        if self.tax_rate:
            return self.line_total_before_tax * (self.tax_rate.rate / 100)
        return 0

    @property
    def line_total(self):
        return self.line_total_before_tax


class InvoiceActivity(models.Model):
    """Audit trail: sent, viewed, paid, etc."""
    invoice    = models.ForeignKey(Invoice, on_delete=models.CASCADE, related_name='activities')
    event      = models.CharField(max_length=100)
    actor      = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    note       = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
