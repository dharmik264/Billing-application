from django.db import models


class Printer(models.Model):
    CONNECTION_CHOICES = [
        ('bluetooth', 'Bluetooth'),
        ('wifi',      'Wi-Fi / Network'),
        ('usb',       'USB'),
    ]
    PAPER_CHOICES = [
        ('58mm',  '58mm'),
        ('80mm',  '80mm'),
    ]

    name            = models.CharField(max_length=100)
    shop            = models.ForeignKey('shop.Shop', on_delete=models.CASCADE, related_name='printers', null=True)
    connection_type = models.CharField(max_length=20, choices=CONNECTION_CHOICES, default='bluetooth')
    address         = models.CharField(max_length=200, blank=True, help_text='IP address or Bluetooth MAC')
    paper_size      = models.CharField(max_length=10, choices=PAPER_CHOICES, default='80mm')
    is_default      = models.BooleanField(default=False)
    is_active       = models.BooleanField(default=True)
    created_at      = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.connection_type})"

    def save(self, *args, **kwargs):
        if self.is_default and self.shop:
            Printer.objects.filter(shop=self.shop).exclude(pk=self.pk).update(is_default=False)
        super().save(*args, **kwargs)


class PrintJob(models.Model):
    STATUS_CHOICES = [
        ('pending',  'Pending'),
        ('printing', 'Printing'),
        ('done',     'Done'),
        ('failed',   'Failed'),
    ]
    JOB_TYPE_CHOICES = [
        ('receipt',     'Receipt'),
        ('kitchen_slip','Kitchen Slip'),
        ('test',        'Test Print'),
    ]

    printer   = models.ForeignKey(Printer, on_delete=models.SET_NULL, null=True, related_name='jobs')
    job_type  = models.CharField(max_length=20, choices=JOB_TYPE_CHOICES)
    token_id  = models.PositiveIntegerField(null=True, blank=True)
    content   = models.TextField(blank=True)   # ESC/POS or text content
    status    = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    error_msg = models.TextField(blank=True)
    created_at= models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.job_type} - {self.status} ({self.created_at:%Y-%m-%d %H:%M})"
