"""
payments/models.py
Payment methods, transactions, refunds, webhooks
"""
import uuid
from django.db import models
from apps.accounts.models import Organisation, User
from apps.invoices.models import Invoice


class PaymentMethod(models.Model):
    class Type(models.TextChoices):
        CARD         = 'card',         'Credit / Debit Card'
        BANK_TRANSFER= 'bank_transfer','Bank Transfer'
        UPI          = 'upi',          'UPI'
        WALLET       = 'wallet',       'Wallet'

    id                   = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    organisation         = models.ForeignKey(Organisation, on_delete=models.CASCADE, related_name='payment_methods')
    type                 = models.CharField(max_length=20, choices=Type.choices)
    stripe_pm_id         = models.CharField(max_length=100, blank=True)
    is_default           = models.BooleanField(default=False)

    # Card details (masked)
    card_brand           = models.CharField(max_length=20, blank=True)
    card_last4           = models.CharField(max_length=4,  blank=True)
    card_exp_month       = models.PositiveSmallIntegerField(null=True, blank=True)
    card_exp_year        = models.PositiveSmallIntegerField(null=True, blank=True)

    # Bank
    bank_name            = models.CharField(max_length=100, blank=True)
    bank_account_last4   = models.CharField(max_length=4,   blank=True)

    created_at           = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-is_default', '-created_at']

    def __str__(self):
        if self.type == self.Type.CARD:
            return f'{self.card_brand} •••• {self.card_last4}'
        return self.get_type_display()

    def save(self, *args, **kwargs):
        if self.is_default:
            PaymentMethod.objects.filter(
                organisation=self.organisation, is_default=True
            ).exclude(pk=self.pk).update(is_default=False)
        super().save(*args, **kwargs)


class Payment(models.Model):
    class Status(models.TextChoices):
        PENDING   = 'pending',   'Pending'
        SUCCEEDED = 'succeeded', 'Succeeded'
        FAILED    = 'failed',    'Failed'
        REFUNDED  = 'refunded',  'Refunded'
        PARTIALLY_REFUNDED = 'partially_refunded', 'Partially Refunded'

    id              = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    organisation    = models.ForeignKey(Organisation, on_delete=models.CASCADE, related_name='payments')
    invoice         = models.ForeignKey(Invoice, on_delete=models.SET_NULL, null=True, blank=True, related_name='payments')
    payment_method  = models.ForeignKey(PaymentMethod, on_delete=models.SET_NULL, null=True, blank=True)

    amount          = models.DecimalField(max_digits=12, decimal_places=2)
    currency        = models.CharField(max_length=3, default='USD')
    status          = models.CharField(max_length=25, choices=Status.choices, default=Status.PENDING)

    stripe_pi_id    = models.CharField(max_length=100, blank=True)
    stripe_charge_id= models.CharField(max_length=100, blank=True)

    description     = models.CharField(max_length=500, blank=True)
    failure_reason  = models.TextField(blank=True)

    paid_at         = models.DateTimeField(null=True, blank=True)
    created_at      = models.DateTimeField(auto_now_add=True)
    updated_at      = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'Payment {self.id} — {self.amount} {self.currency} ({self.status})'


class Refund(models.Model):
    class Status(models.TextChoices):
        PENDING   = 'pending',   'Pending'
        SUCCEEDED = 'succeeded', 'Succeeded'
        FAILED    = 'failed',    'Failed'

    id               = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    payment          = models.ForeignKey(Payment, on_delete=models.CASCADE, related_name='refunds')
    amount           = models.DecimalField(max_digits=12, decimal_places=2)
    reason           = models.CharField(max_length=200, blank=True)
    status           = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    stripe_refund_id = models.CharField(max_length=100, blank=True)
    initiated_by     = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    created_at       = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'Refund {self.id} — {self.amount}'


class WebhookEvent(models.Model):
    """Log incoming Stripe webhook events."""
    stripe_event_id = models.CharField(max_length=100, unique=True)
    event_type      = models.CharField(max_length=100)
    payload         = models.JSONField()
    is_processed    = models.BooleanField(default=False)
    error           = models.TextField(blank=True)
    received_at     = models.DateTimeField(auto_now_add=True)
    processed_at    = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-received_at']

    def __str__(self):
        return f'{self.event_type} ({self.stripe_event_id})'
