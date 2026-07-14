from django.contrib import admin
from django.http import HttpResponse
import csv
from .models import Customer


@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display   = ['name', 'mobile_number', 'gst_number', 'status', 'created_at']
    list_filter    = ['status', 'created_at']
    search_fields  = ['name', 'mobile_number', 'gst_number', 'address']
    list_editable  = ['status']
    readonly_fields = ['created_at', 'updated_at']
    ordering       = ['-created_at']
    actions        = ['export_as_csv']

    fieldsets = (
        ('Customer Information', {
            'fields': ('shop', 'name', 'mobile_number', 'address', 'gst_number', 'status')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',),
        }),
    )

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

    @admin.action(description='Export selected customers as CSV')
    def export_as_csv(self, request, queryset):
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="customers.csv"'
        writer = csv.writer(response)
        writer.writerow(['ID', 'Name', 'Mobile Number', 'GST Number', 'Address', 'Status', 'Created At'])
        for customer in queryset:
            writer.writerow([
                customer.id,
                customer.name,
                customer.mobile_number,
                customer.gst_number,
                customer.address,
                customer.get_status_display(),
                customer.created_at.strftime('%Y-%m-%d %H:%M'),
            ])
        return response
