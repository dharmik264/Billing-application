"""
reports/models.py — Saved/scheduled reports
"""
import uuid
from django.db import models
from apps.accounts.models import Organisation, User


class SavedReport(models.Model):
    class ReportType(models.TextChoices):
        REVENUE      = 'revenue',      'Revenue Report'
        INVOICES     = 'invoices',     'Invoice Summary'
        SUBSCRIPTIONS= 'subscriptions','Subscription Analytics'
        PAYMENTS     = 'payments',     'Payment Report'
        CHURN        = 'churn',        'Churn Analysis'
        MRR          = 'mrr',          'MRR / ARR Report'

    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    organisation = models.ForeignKey(Organisation, on_delete=models.CASCADE)
    created_by   = models.ForeignKey(User, on_delete=models.SET_NULL, null=True)
    name         = models.CharField(max_length=200)
    report_type  = models.CharField(max_length=30, choices=ReportType.choices)
    filters      = models.JSONField(default=dict)   # date_from, date_to, currency, etc.
    created_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
