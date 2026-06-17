from django.contrib import admin
from .models import PaymentMethod, Payment, Refund, WebhookEvent

@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ('id', 'organisation', 'amount', 'currency', 'status', 'paid_at')
    list_filter  = ('status', 'currency')

admin.site.register(PaymentMethod)
admin.site.register(Refund)
admin.site.register(WebhookEvent)
