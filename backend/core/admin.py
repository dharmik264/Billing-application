from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, OTP, AppSettings


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display  = ['phone', 'name', 'is_active', 'is_staff', 'created_at']
    search_fields = ['phone', 'name']
    ordering      = ['-created_at']
    fieldsets = (
        (None,            {'fields': ('phone', 'password')}),
        ('Personal info', {'fields': ('name',)}),
        ('Permissions',   {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
    )
    add_fieldsets = (
        (None, {'classes': ('wide',), 'fields': ('phone', 'password1', 'password2')}),
    )

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        return qs.filter(id=request.user.id)


@admin.register(OTP)
class OTPAdmin(admin.ModelAdmin):
    list_display  = ['phone', 'code', 'is_used', 'created_at']
    list_filter   = ['is_used']
    search_fields = ['phone']


@admin.register(AppSettings)
class AppSettingsAdmin(admin.ModelAdmin):
    list_display = ['gst_enabled', 'gst_percentage', 'service_charge', 'currency_symbol']

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        return qs.filter(shop=shop)

    def save_model(self, request, obj, form, change):
        if not request.user.is_superuser and not getattr(obj, 'shop_id', None):
            from shop.models import Shop
            obj.shop = Shop.get_shop(request.user)
        super().save_model(request, obj, form, change)
