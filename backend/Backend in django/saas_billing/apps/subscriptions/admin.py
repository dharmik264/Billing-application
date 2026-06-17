from django.contrib import admin
from .models import Plan, PlanFeature, Subscription, SubscriptionHistory, UsageRecord

class PlanFeatureInline(admin.TabularInline):
    model = PlanFeature
    extra = 1

@admin.register(Plan)
class PlanAdmin(admin.ModelAdmin):
    list_display = ('name', 'price', 'billing_interval', 'is_active', 'is_public')
    list_filter  = ('billing_interval', 'is_active', 'is_public')
    inlines      = [PlanFeatureInline]

@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display  = ('organisation', 'plan', 'status', 'current_period_end')
    list_filter   = ('status',)
    search_fields = ('organisation__name',)

admin.site.register(SubscriptionHistory)
admin.site.register(UsageRecord)
