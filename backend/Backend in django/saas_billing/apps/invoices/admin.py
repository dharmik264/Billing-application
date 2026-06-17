from django.contrib import admin
from .models import Invoice, LineItem, TaxRate, InvoiceActivity

class LineItemInline(admin.TabularInline):
    model = LineItem
    extra = 1

@admin.register(Invoice)
class InvoiceAdmin(admin.ModelAdmin):
    list_display  = ('invoice_number', 'organisation', 'status', 'total', 'due_date')
    list_filter   = ('status', 'currency')
    search_fields = ('invoice_number', 'bill_to_name', 'bill_to_email')
    inlines       = [LineItemInline]

admin.site.register(TaxRate)
admin.site.register(InvoiceActivity)
