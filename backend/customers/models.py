import re
from django.db import models


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
