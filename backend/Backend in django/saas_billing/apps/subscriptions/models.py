"""
subscriptions/models.py
Plans, Features, Subscriptions, Usage tracking
"""
import uuid
from django.db import models
from django.utils import timezone
from apps.accounts.models import Organisation


class Plan(models.Model):
    class BillingInterval(models.TextChoices):
        MONTHLY  = 'monthly',  'Monthly'
        YEARLY   = 'yearly',   'Yearly'
        WEEKLY   = 'weekly',   'Weekly'

    id          = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name        = models.CharField(max_length=100)
    slug        = models.SlugField(unique=True)
    description = models.TextField(blank=True)

    price              = models.DecimalField(max_digits=10, decimal_places=2)
    billing_interval   = models.CharField(max_length=10, choices=BillingInterval.choices, default=BillingInterval.MONTHLY)
    currency           = models.CharField(max_length=3, default='USD')

    # Stripe IDs
    stripe_price_id   = models.CharField(max_length=100, blank=True)
    stripe_product_id = models.CharField(max_length=100, blank=True)

    trial_days  = models.PositiveIntegerField(default=0)
    is_active   = models.BooleanField(default=True)
    is_public   = models.BooleanField(default=True)
    sort_order  = models.PositiveIntegerField(default=0)

    # Limits
    max_users   = models.PositiveIntegerField(null=True, blank=True, help_text='null = unlimited')
    max_invoices_per_month = models.PositiveIntegerField(null=True, blank=True)

    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['sort_order', 'price']

    def __str__(self):
        return f'{self.name} ({self.get_billing_interval_display()})'


class PlanFeature(models.Model):
    plan        = models.ForeignKey(Plan, on_delete=models.CASCADE, related_name='features')
    name        = models.CharField(max_length=200)
    description = models.CharField(max_length=500, blank=True)
    is_included = models.BooleanField(default=True)
    limit_value = models.IntegerField(null=True, blank=True, help_text='null = unlimited')

    def __str__(self):
        return f'{self.plan.name} — {self.name}'


class Subscription(models.Model):
    class Status(models.TextChoices):
        TRIALING  = 'trialing',  'Trialing'
        ACTIVE    = 'active',    'Active'
        PAST_DUE  = 'past_due',  'Past Due'
        CANCELED  = 'canceled',  'Canceled'
        PAUSED    = 'paused',    'Paused'
        INCOMPLETE = 'incomplete', 'Incomplete'

    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    organisation = models.OneToOneField(Organisation, on_delete=models.CASCADE, related_name='subscription')
    plan         = models.ForeignKey(Plan, on_delete=models.PROTECT, related_name='subscriptions')

    status            = models.CharField(max_length=20, choices=Status.choices, default=Status.TRIALING)
    stripe_sub_id     = models.CharField(max_length=100, blank=True)

    # Dates
    trial_start  = models.DateTimeField(null=True, blank=True)
    trial_end    = models.DateTimeField(null=True, blank=True)
    current_period_start = models.DateTimeField(null=True, blank=True)
    current_period_end   = models.DateTimeField(null=True, blank=True)
    canceled_at  = models.DateTimeField(null=True, blank=True)
    cancel_at    = models.DateTimeField(null=True, blank=True)  # scheduled cancellation

    # Discount
    discount_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    coupon_code      = models.CharField(max_length=50, blank=True)

    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.organisation.name} — {self.plan.name} ({self.status})'

    @property
    def is_active(self):
        return self.status in (self.Status.ACTIVE, self.Status.TRIALING)

    @property
    def is_in_trial(self):
        return self.status == self.Status.TRIALING and self.trial_end and timezone.now() < self.trial_end


class SubscriptionHistory(models.Model):
    """Audit log of all subscription changes."""
    subscription = models.ForeignKey(Subscription, on_delete=models.CASCADE, related_name='history')
    event        = models.CharField(max_length=100)  # e.g. 'plan_changed', 'canceled'
    old_plan     = models.ForeignKey(Plan, null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    new_plan     = models.ForeignKey(Plan, null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    old_status   = models.CharField(max_length=20, blank=True)
    new_status   = models.CharField(max_length=20, blank=True)
    note         = models.TextField(blank=True)
    created_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class UsageRecord(models.Model):
    """Track metered usage (e.g. API calls, invoices generated)."""
    subscription = models.ForeignKey(Subscription, on_delete=models.CASCADE, related_name='usage_records')
    metric       = models.CharField(max_length=100)   # e.g. 'invoices_generated'
    quantity     = models.PositiveIntegerField(default=1)
    recorded_at  = models.DateTimeField(auto_now_add=True)
    period_start = models.DateTimeField()
    period_end   = models.DateTimeField()

    class Meta:
        ordering = ['-recorded_at']
