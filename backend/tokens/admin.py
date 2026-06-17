from django.contrib import admin
from .models import Token, TokenItem

class TokenItemInline(admin.TabularInline):
    model = TokenItem
    extra = 0
    readonly_fields = ['subtotal']

@admin.register(Token)
class TokenAdmin(admin.ModelAdmin):
    list_display  = ['token_number', 'date', 'order_type', 'table_number', 'status', 'total', 'is_paid', 'payment_mode']
    list_filter   = ['status', 'is_paid', 'order_type', 'date']
    search_fields = ['token_number', 'customer_name', 'customer_phone']
    inlines       = [TokenItemInline]
    readonly_fields = ['token_number', 'subtotal', 'gst_amount', 'service_charge', 'total']

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
