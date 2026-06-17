from django.db import models
from django.utils import timezone
from menu.models import MenuItem


class Token(models.Model):
    STATUS_CHOICES = [
        ('open',      'Open'),
        ('preparing', 'Preparing'),
        ('ready',     'Ready'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    ORDER_TYPE_CHOICES = [
        ('dine_in',   'Dine In'),
        ('takeaway',  'Takeaway'),
        ('delivery',  'Delivery'),
    ]

    shop          = models.ForeignKey('shop.Shop', on_delete=models.CASCADE, related_name='tokens', null=True)
    token_number  = models.PositiveIntegerField()
    bill_number   = models.CharField(max_length=20, blank=True)
    date          = models.DateField(default=timezone.localdate)
    order_type    = models.CharField(max_length=20, choices=ORDER_TYPE_CHOICES, default='dine_in')
    table_number  = models.CharField(max_length=10, blank=True)
    customer_name = models.CharField(max_length=100, blank=True)
    customer_phone= models.CharField(max_length=15, blank=True)
    status        = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open')
    note          = models.TextField(blank=True)

    # Billing
    subtotal      = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    gst_amount    = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    service_charge= models.DecimalField(max_digits=10, decimal_places=2, default=0)
    discount      = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total         = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    is_paid       = models.BooleanField(default=False)
    payment_mode  = models.CharField(max_length=20, blank=True)   # cash / upi / card

    created_at    = models.DateTimeField(auto_now_add=True)
    updated_at    = models.DateTimeField(auto_now=True)

    class Meta:
        ordering             = ['-created_at']
        unique_together      = ['shop', 'token_number', 'date']

    def __str__(self):
        return f"Token #{self.token_number} ({self.bill_number})"

    @classmethod
    def get_next_token_number(cls, shop):
        if not shop:
            raise ValueError("Shop is required")
        today = timezone.localdate()
        last  = cls.objects.filter(shop=shop, date=today).order_by('-token_number').first()
        return (last.token_number + 1) if last else 1

    def calculate_totals(self):
        from core.models import AppSettings
        settings = AppSettings.get_settings(self.shop)
        from decimal import Decimal
        self.subtotal = Decimal(str(sum(item.subtotal for item in self.items.all())))
        if settings.gst_enabled:
            self.gst_amount = self.subtotal * Decimal(str(settings.gst_percentage)) / Decimal('100')
        else:
            self.gst_amount = Decimal('0')
        self.service_charge = self.subtotal * Decimal(str(settings.service_charge)) / Decimal('100')
        self.total = self.subtotal + self.gst_amount + self.service_charge - Decimal(str(self.discount))
        self.save(update_fields=['subtotal', 'gst_amount', 'service_charge', 'total'])


class TokenItem(models.Model):
    token     = models.ForeignKey(Token, on_delete=models.CASCADE, related_name='items')
    menu_item = models.ForeignKey(MenuItem, on_delete=models.SET_NULL, null=True)
    name      = models.CharField(max_length=200)   # snapshot
    price     = models.DecimalField(max_digits=10, decimal_places=2)  # snapshot
    quantity  = models.PositiveIntegerField(default=1)
    note      = models.TextField(blank=True)

    class Meta:
        ordering = ['id']

    @property
    def subtotal(self):
        return self.price * self.quantity

    def __str__(self):
        return f"{self.name} x{self.quantity}"
