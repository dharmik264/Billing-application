from rest_framework import serializers
from .models import Token, TokenItem


class TokenItemSerializer(serializers.ModelSerializer):
    subtotal = serializers.ReadOnlyField()

    class Meta:
        model  = TokenItem
        fields = ['id', 'menu_item', 'name', 'price', 'quantity', 'note', 'subtotal']


class TokenItemWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model  = TokenItem
        fields = ['menu_item', 'quantity', 'note']


class TokenSerializer(serializers.ModelSerializer):
    items = TokenItemSerializer(many=True, read_only=True)

    class Meta:
        model  = Token
        fields = [
            'id', 'token_number', 'bill_number', 'date', 'order_type', 'table_number',
            'customer_name', 'customer_phone', 'status', 'note',
            'subtotal', 'gst_amount', 'service_charge', 'discount', 'total',
            'is_paid', 'payment_mode', 'items', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'date', 'subtotal', 'gst_amount',
                            'service_charge', 'total', 'created_at', 'updated_at']


class CreateTokenSerializer(serializers.Serializer):
    token_number   = serializers.IntegerField(required=False)
    bill_number    = serializers.CharField(max_length=20, required=False, allow_blank=True)
    order_type     = serializers.ChoiceField(choices=Token.ORDER_TYPE_CHOICES, default='dine_in')
    table_number   = serializers.CharField(max_length=10, required=False, allow_blank=True)
    customer_name  = serializers.CharField(max_length=100, required=False, allow_blank=True)
    customer_phone = serializers.CharField(max_length=15, required=False, allow_blank=True)
    note           = serializers.CharField(required=False, allow_blank=True)
    payment_mode   = serializers.CharField(max_length=50, required=False, allow_blank=True)
    is_paid        = serializers.BooleanField(required=False, default=False)
    items          = serializers.ListField(
        child=serializers.DictField(), min_length=1
    )


class UpdateTokenStatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=Token.STATUS_CHOICES)


class PaymentSerializer(serializers.Serializer):
    payment_mode = serializers.ChoiceField(choices=['cash', 'upi', 'card', 'online'])
    discount     = serializers.DecimalField(max_digits=10, decimal_places=2, default=0, required=False)


class TokenListSerializer(serializers.ModelSerializer):
    item_count = serializers.SerializerMethodField()
    items = TokenItemSerializer(many=True, read_only=True)

    class Meta:
        model  = Token
        fields = [
            'id', 'token_number', 'bill_number', 'date', 'order_type', 'table_number',
            'customer_name', 'customer_phone', 'status', 'total', 'is_paid', 'payment_mode',
            'item_count', 'created_at', 'items'
        ]

    def get_item_count(self, obj):
        return sum(i.quantity for i in obj.items.all())
