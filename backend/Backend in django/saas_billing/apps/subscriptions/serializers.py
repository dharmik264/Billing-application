"""
subscriptions/serializers.py
"""
from rest_framework import serializers
from .models import Plan, PlanFeature, Subscription, SubscriptionHistory, UsageRecord


class PlanFeatureSerializer(serializers.ModelSerializer):
    class Meta:
        model  = PlanFeature
        fields = ['id', 'name', 'description', 'is_included', 'limit_value']


class PlanSerializer(serializers.ModelSerializer):
    features = PlanFeatureSerializer(many=True, read_only=True)

    class Meta:
        model  = Plan
        fields = [
            'id', 'name', 'slug', 'description', 'price', 'billing_interval',
            'currency', 'trial_days', 'is_active', 'is_public',
            'max_users', 'max_invoices_per_month', 'features', 'sort_order',
        ]
        read_only_fields = ['id']


class SubscriptionSerializer(serializers.ModelSerializer):
    plan         = PlanSerializer(read_only=True)
    plan_id      = serializers.UUIDField(write_only=True)
    days_until_renewal = serializers.SerializerMethodField()

    class Meta:
        model  = Subscription
        fields = [
            'id', 'plan', 'plan_id', 'status',
            'trial_start', 'trial_end',
            'current_period_start', 'current_period_end',
            'canceled_at', 'cancel_at',
            'discount_percent', 'coupon_code',
            'days_until_renewal', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'status', 'trial_start', 'trial_end',
                            'current_period_start', 'current_period_end',
                            'canceled_at', 'created_at', 'updated_at']

    def get_days_until_renewal(self, obj):
        if obj.current_period_end:
            from django.utils import timezone
            delta = obj.current_period_end - timezone.now()
            return max(0, delta.days)
        return None


class ChangePlanSerializer(serializers.Serializer):
    plan_id     = serializers.UUIDField()
    prorate     = serializers.BooleanField(default=True)


class SubscriptionHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model  = SubscriptionHistory
        fields = ['id', 'event', 'old_plan', 'new_plan', 'old_status', 'new_status', 'note', 'created_at']


class UsageRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model  = UsageRecord
        fields = ['id', 'metric', 'quantity', 'recorded_at', 'period_start', 'period_end']
