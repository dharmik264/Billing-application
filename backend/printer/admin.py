from django.contrib import admin
from .models import Printer, PrintJob

@admin.register(Printer)
class PrinterAdmin(admin.ModelAdmin):
    list_display = ['name', 'connection_type', 'address', 'paper_size', 'is_default', 'is_active']

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

@admin.register(PrintJob)
class PrintJobAdmin(admin.ModelAdmin):
    list_display = ['job_type', 'token_id', 'printer', 'status', 'created_at']
    list_filter  = ['job_type', 'status']

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        # Assuming printer relation
        return qs.filter(printer__shop=shop)
