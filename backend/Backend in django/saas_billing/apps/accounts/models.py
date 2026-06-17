"""
accounts/models.py
Custom User model + Organisation model for SaaS multi-tenancy.
"""
import uuid
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models
from django.utils import timezone


class UserManager(BaseUserManager):
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', User.Role.ADMIN)
        return self.create_user(email, password, **extra_fields)


class Organisation(models.Model):
    id   = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    slug = models.SlugField(unique=True)
    logo = models.ImageField(upload_to='org_logos/', null=True, blank=True)

    # Billing address
    address_line1 = models.CharField(max_length=255, blank=True)
    address_line2 = models.CharField(max_length=255, blank=True)
    city          = models.CharField(max_length=100, blank=True)
    state         = models.CharField(max_length=100, blank=True)
    postal_code   = models.CharField(max_length=20,  blank=True)
    country       = models.CharField(max_length=2,   default='US')

    # Stripe customer ID
    stripe_customer_id = models.CharField(max_length=100, blank=True)

    tax_id   = models.CharField(max_length=50, blank=True)
    timezone = models.CharField(max_length=50, default='UTC')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        return self.name


class User(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        ADMIN        = 'admin',   'Admin'
        BILLING_MGR  = 'billing', 'Billing Manager'
        MEMBER       = 'member',  'Member'
        VIEWER       = 'viewer',  'Viewer'

    id           = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email        = models.EmailField(unique=True)
    first_name   = models.CharField(max_length=100)
    last_name    = models.CharField(max_length=100)
    role         = models.CharField(max_length=20, choices=Role.choices, default=Role.MEMBER)
    organisation = models.ForeignKey(
        Organisation, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='members'
    )
    avatar       = models.ImageField(upload_to='avatars/', null=True, blank=True)
    phone        = models.CharField(max_length=20, blank=True)

    is_active    = models.BooleanField(default=True)
    is_staff     = models.BooleanField(default=False)
    is_verified  = models.BooleanField(default=False)

    date_joined  = models.DateTimeField(default=timezone.now)
    last_login   = models.DateTimeField(null=True, blank=True)

    objects = UserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['first_name', 'last_name']

    class Meta:
        ordering = ['email']
        verbose_name = 'User'
        verbose_name_plural = 'Users'

    def __str__(self):
        return f'{self.get_full_name()} <{self.email}>'

    def get_full_name(self):
        return f'{self.first_name} {self.last_name}'.strip()

    @property
    def is_admin(self):
        return self.role == self.Role.ADMIN

    @property
    def is_billing_manager(self):
        return self.role in (self.Role.ADMIN, self.Role.BILLING_MGR)


class EmailVerificationToken(models.Model):
    user       = models.ForeignKey(User, on_delete=models.CASCADE, related_name='verification_tokens')
    token      = models.UUIDField(default=uuid.uuid4, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used    = models.BooleanField(default=False)

    def is_valid(self):
        return not self.is_used and timezone.now() < self.expires_at


class PasswordResetToken(models.Model):
    user       = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reset_tokens')
    token      = models.UUIDField(default=uuid.uuid4, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used    = models.BooleanField(default=False)

    def is_valid(self):
        return not self.is_used and timezone.now() < self.expires_at
