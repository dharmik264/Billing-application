from rest_framework import serializers
from .models import PaymentMethod, Payment, Refund


class PaymentMethodSerializer(serializers.ModelSerializer):
    display_name = serializers.SerializerMethodField()

    class Meta:
        model  = PaymentMethod
        fields = [
            'id', 'type', 'is_default', 'display_name',
            'card_brand', 'card_last4', 'card_exp_month', 'card_exp_year',
            'bank_name', 'bank_account_last4', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']

    def get_display_name(self, obj):
        return str(obj)


class AddPaymentMethodSerializer(serializers.Serializer):
    payment_method_id = serializers.CharField()  # Stripe PM ID from frontend
    set_default       = serializers.BooleanField(default=False)


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Payment
        fields = [
            'id', 'invoice', 'payment_method', 'amount', 'currency',
            'status', 'description', 'failure_reason', 'paid_at', 'created_at',
        ]
        read_only_fields = ['id', 'status', 'paid_at', 'created_at']


class CreatePaymentSerializer(serializers.Serializer):
    invoice_id        = serializers.UUIDField()
    payment_method_id = serializers.UUIDField()


class RefundSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Refund
        fields = ['id', 'payment', 'amount', 'reason', 'status', 'created_at']
        read_only_fields = ['id', 'status', 'created_at']


class CreateRefundSerializer(serializers.Serializer):
    payment_id = serializers.UUIDField()
    amount     = serializers.DecimalField(max_digits=12, decimal_places=2)
    reason     = serializers.CharField(max_length=200, required=False, default='')
