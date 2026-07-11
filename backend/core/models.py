from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models
from django.utils import timezone
import random, string


ACCOUNT_STATUS_CHOICES = [
    ('pending', 'Pending Approval'),
    ('trial', 'Trial Period'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
    ('expired', 'Trial Expired'),
]

class UserManager(BaseUserManager):
    def create_user(self, phone, **extra_fields):
        if not phone:
            raise ValueError('Phone number is required')
        user = self.model(phone=phone, **extra_fields)
        user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, phone, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        user = self.model(phone=phone, **extra_fields)
        if password:
            user.set_password(password)
        user.save(using=self._db)
        return user


class User(AbstractBaseUser, PermissionsMixin):
    phone          = models.CharField(max_length=15, unique=True)
    name           = models.CharField(max_length=100, blank=True)
    email          = models.EmailField(blank=True)
    shop_name      = models.CharField(max_length=200, blank=True)
    account_status = models.CharField(max_length=20, choices=ACCOUNT_STATUS_CHOICES, default='pending')
    trial_start    = models.DateTimeField(null=True, blank=True)
    trial_end      = models.DateTimeField(null=True, blank=True)
    approved_plan  = models.CharField(max_length=50, blank=True)
    approved_at    = models.DateTimeField(null=True, blank=True)
    is_active      = models.BooleanField(default=True)
    is_staff       = models.BooleanField(default=False)
    permissions    = models.JSONField(default=dict, blank=True)
    created_at     = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD  = 'phone'
    REQUIRED_FIELDS = []
    objects = UserManager()

    def __str__(self):
        return self.phone

    @property
    def is_trial_active(self):
        if self.account_status != 'trial' or not self.trial_end:
            return False
        return timezone.now() <= self.trial_end

    @property
    def can_login(self):
        """User can login if approved, or in active trial"""
        if self.phone == '9999999999':  # Super Admin bypass
            return True
        if self.account_status == 'approved':
            return True
        if self.account_status == 'trial' and self.is_trial_active:
            return True
        return False


class OTP(models.Model):
    phone      = models.CharField(max_length=15)
    code       = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_used    = models.BooleanField(default=False)

    class Meta:
        ordering = ['-created_at']

    def is_expired(self):
        from django.conf import settings
        from datetime import timedelta
        expiry = self.created_at + timedelta(minutes=getattr(settings, 'OTP_EXPIRY_MINUTES', 5))
        return timezone.now() > expiry

    @classmethod
    def generate_code(cls):
        return ''.join(random.choices(string.digits, k=4))

    def __str__(self):
        return f"{self.phone} - {self.code}"


class AppSettings(models.Model):
    """Global app settings (singleton per shop)"""
    shop             = models.OneToOneField('shop.Shop', on_delete=models.CASCADE, related_name='settings', null=True)
    gst_enabled      = models.BooleanField(default=True)
    gst_percentage   = models.DecimalField(max_digits=5, decimal_places=2, default=5.00)
    service_charge   = models.DecimalField(max_digits=5, decimal_places=2, default=0.00)
    currency_symbol  = models.CharField(max_length=5, default='₹')
    receipt_footer   = models.TextField(blank=True, default='Thank you for visiting!')
    auto_print       = models.BooleanField(default=False)
    sound_enabled    = models.BooleanField(default=True)
    created_at       = models.DateTimeField(auto_now_add=True)
    updated_at       = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'App Settings'

    def __str__(self):
        return "App Settings"

    @classmethod
    def get_settings(cls, shop):
        if not shop:
            raise ValueError("Shop is required")
        obj, _ = cls.objects.get_or_create(shop=shop)
        return obj


class SubscriptionPlan(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    price_monthly = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    price_yearly = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    
    # Usage limits
    max_users = models.IntegerField(default=1) # 1 for individual, e.g. 5 for pro
    max_tables = models.IntegerField(default=0) # 0 for no limit or unlimited, depending on logic
    max_invoices_per_month = models.IntegerField(default=-1) # -1 for unlimited
    
    # JSON features linked to permissions system (billing, inventory, reports, tax, staff)
    features = models.JSONField(default=dict, blank=True)
    
    # Flags
    is_active = models.BooleanField(default=True)
    is_popular = models.BooleanField(default=False)
    trial_days = models.IntegerField(default=0)
    display_order = models.IntegerField(default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['display_order', 'id']

    def __str__(self):
        return self.name

class SystemSettings(models.Model):
    payment_qr_code = models.ImageField(upload_to='system/qr_codes/', null=True, blank=True)
    payment_upi_id = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'System Settings'
        verbose_name_plural = 'System Settings'

    def __str__(self):
        return 'Global System Settings'

    @classmethod
    def get_settings(cls):
        obj, _ = cls.objects.get_or_create(id=1)
        return obj


class SubscriptionPayment(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending Verification'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    BILLING_CYCLE_CHOICES = [
        ('monthly', 'Monthly'),
        ('yearly', 'Yearly'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='subscription_payments')
    plan = models.ForeignKey(SubscriptionPlan, on_delete=models.SET_NULL, null=True)
    billing_cycle = models.CharField(max_length=20, choices=BILLING_CYCLE_CHOICES, default='monthly')
    transaction_id = models.CharField(max_length=100)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    amount_paid = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    notes = models.TextField(blank=True, help_text='Admin notes or rejection reason')
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.user.phone} - {self.plan.name if self.plan else "Unknown"} ({self.status})'
