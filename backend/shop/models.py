from django.db import models


from django.conf import settings

class Shop(models.Model):
    owner                = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='shop', null=True)
    name                 = models.CharField(max_length=200)
    tagline              = models.CharField(max_length=200, blank=True)
    address              = models.TextField(blank=True)
    phone                = models.CharField(max_length=15, blank=True)
    alternate_phone      = models.CharField(max_length=15, blank=True)
    email                = models.EmailField(blank=True)
    gstin                = models.CharField(max_length=20, blank=True, verbose_name='GSTIN')
    fssai                = models.CharField(max_length=20, blank=True, verbose_name='FSSAI Number')
    logo                 = models.ImageField(upload_to='shop/logos/', null=True, blank=True)
    qr_code              = models.ImageField(upload_to='shop/qr_codes/', null=True, blank=True)
    payment_modes_config = models.CharField(max_length=20, default='Both')
    opening_time         = models.TimeField(null=True, blank=True)
    closing_time         = models.TimeField(null=True, blank=True)
    table_count          = models.PositiveIntegerField(default=0)
    upi_id               = models.CharField(max_length=100, blank=True, verbose_name='UPI ID')
    bill_settings        = models.JSONField(default=dict, blank=True) # Kept for legacy/fallback
    created_at           = models.DateTimeField(auto_now_add=True)
    updated_at    = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Shop'

    def __str__(self):
        return self.name

    @classmethod
    def get_shop(cls, user):
        if not user:
            raise ValueError("User is required")
        obj, _ = cls.objects.get_or_create(owner=user, defaults={'name': 'My Restaurant'})
        return obj


class BillTemplate(models.Model):
    shop = models.OneToOneField(Shop, on_delete=models.CASCADE, related_name='bill_template')
    logo_url = models.ImageField(upload_to='bill_templates/logos/', null=True, blank=True)
    shop_name = models.CharField(max_length=200, blank=True)
    tagline = models.CharField(max_length=200, blank=True)
    mobile_number = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True)
    address = models.TextField(blank=True)
    gst_number = models.CharField(max_length=20, blank=True)
    qr_code_url = models.ImageField(upload_to='bill_templates/qr_codes/', null=True, blank=True)
    
    show_invoice_number = models.BooleanField(default=True)
    show_date_time = models.BooleanField(default=True)
    show_customer_details = models.BooleanField(default=True)
    show_discount = models.BooleanField(default=True)
    show_tax = models.BooleanField(default=True)
    
    # Extra fields for granular control requested
    show_item_name = models.BooleanField(default=True)
    show_quantity = models.BooleanField(default=True)
    show_unit_price = models.BooleanField(default=True)
    show_total_price = models.BooleanField(default=True)
    show_subtotal = models.BooleanField(default=True)
    show_round_off = models.BooleanField(default=True)
    show_grand_total = models.BooleanField(default=True)
    show_payment_method = models.BooleanField(default=True)
    show_upi_id = models.BooleanField(default=True)
    
    footer_message = models.TextField(blank=True, default="Thank you for visiting!")
    terms_and_conditions = models.TextField(blank=True)
    theme_color = models.CharField(max_length=50, blank=True, default='#000000')
    template_design = models.CharField(max_length=50, blank=True, default='standard')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Bill Template'

    def __str__(self):
        return f"Bill Template for {self.shop.name}"

    @classmethod
    def get_template(cls, shop):
        if not shop:
            raise ValueError("Shop is required")
        obj, _ = cls.objects.get_or_create(shop=shop)
        return obj
