from django.contrib import admin
from .models import Category, MenuItem

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'icon', 'sort_order', 'is_active']
    list_editable = ['sort_order', 'is_active']

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

@admin.register(MenuItem)
class MenuItemAdmin(admin.ModelAdmin):
    list_display  = ['name', 'category', 'price', 'item_type', 'is_available', 'is_featured']
    list_filter   = ['category', 'item_type', 'is_available']
    search_fields = ['name']
    list_editable = ['price', 'is_available']

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
