"""
payments/webhook_handlers.py
Process Stripe webhook events.
"""
from django.utils import timezone


def handle(event):
    handlers = {
        'payment_intent.succeeded':            _payment_succeeded,
        'payment_intent.payment_failed':       _payment_failed,
        'invoice.paid':                        _invoice_paid,
        'invoice.payment_failed':              _invoice_payment_failed,
        'customer.subscription.updated':       _subscription_updated,
        'customer.subscription.deleted':       _subscription_deleted,
    }
    handler = handlers.get(event.type)
    if handler:
        handler(event.data.object)


def _payment_succeeded(obj):
    from .models import Payment
    Payment.objects.filter(stripe_pi_id=obj.id).update(
        status=Payment.Status.SUCCEEDED, paid_at=timezone.now()
    )


def _payment_failed(obj):
    from .models import Payment
    Payment.objects.filter(stripe_pi_id=obj.id).update(
        status=Payment.Status.FAILED,
        failure_reason=obj.get('last_payment_error', {}).get('message', '')
    )


def _invoice_paid(obj):
    from apps.invoices.models import Invoice
    Invoice.objects.filter(stripe_invoice_id=obj.id).update(
        status='paid', paid_at=timezone.now()
    )


def _invoice_payment_failed(obj):
    from apps.invoices.models import Invoice
    Invoice.objects.filter(stripe_invoice_id=obj.id).update(status='past_due')


def _subscription_updated(obj):
    from apps.subscriptions.models import Subscription
    Subscription.objects.filter(stripe_sub_id=obj.id).update(status=obj.status)


def _subscription_deleted(obj):
    from apps.subscriptions.models import Subscription
    Subscription.objects.filter(stripe_sub_id=obj.id).update(status='canceled')
