import re
from django.db import models


from django.utils import timezone

GST_REGEX = re.compile(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$'
)


class Customer(models.Model):
    STATUS_CHOICES = [
        ('active',   'Active'),
        ('inactive', 'Inactive'),
    ]

    name          = models.CharField(max_length=200)
    mobile_number = models.CharField(max_length=10, unique=True)
    address       = models.TextField(blank=True, null=True)
    gst_number    = models.CharField(max_length=15, blank=True, default='')
    status        = models.CharField(max_length=10, choices=STATUS_CHOICES, default='active')
    created_at    = models.DateTimeField(auto_now_add=True)
    updated_at    = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        # Mobile is unique per tenant schema

    def __str__(self):
        return f"{self.name} ({self.mobile_number})"


class CustomerPayment(models.Model):
    customer       = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='payments')
    token          = models.ForeignKey('tokens.Token', null=True, blank=True, on_delete=models.SET_NULL, related_name='payments')
    payment_number = models.CharField(max_length=50, blank=True)
    amount         = models.DecimalField(max_digits=10, decimal_places=2)
    payment_mode   = models.CharField(max_length=20, default='cash')
    date           = models.DateField(default=timezone.localdate)
    note           = models.TextField(blank=True)
    created_at     = models.DateTimeField(auto_now_add=True)


    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Payment #{self.payment_number or self.id} - ₹{self.amount} ({self.customer.name})"

    @classmethod
    def get_next_payment_number(cls):
        max_id = cls.objects.aggregate(m=models.Max('id'))['m'] or 0
        return f"P{max_id + 1:04d}"

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        if not self.payment_number:
            self.payment_number = f"P{self.id:04d}"
            super().save(update_fields=['payment_number'])

