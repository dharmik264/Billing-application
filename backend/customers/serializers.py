import re
from rest_framework import serializers
from .models import Customer

GST_REGEX = re.compile(
    r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$'
)


class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Customer
        fields = [
            'id', 'name', 'mobile_number', 'address',
            'gst_number', 'status', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    # ── Field-level validation ─────────────────────────────────

    def validate_name(self, value):
        value = value.strip()
        if len(value) < 3:
            raise serializers.ValidationError(
                'Name must be at least 3 characters long.'
            )
        return value

    def validate_address(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError(
                'Address cannot be empty.'
            )
        return value

    def validate_mobile_number(self, value):
        value = value.strip()
        if not value.isdigit():
            raise serializers.ValidationError(
                'Mobile number must contain only digits.'
            )
        if len(value) != 10:
            raise serializers.ValidationError(
                'Mobile number must be exactly 10 digits.'
            )
        return value

    def validate_gst_number(self, value):
        value = value.strip().upper()
        if value and not GST_REGEX.match(value):
            raise serializers.ValidationError(
                'Invalid GST number format. '
                'Expected format: 22AAAAA0000A1Z5'
            )
        return value

    # ── Cross-field uniqueness check ───────────────────────────

    def validate(self, attrs):
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            from shop.models import Shop
            shop = Shop.get_shop(request.user)
            mobile = attrs.get('mobile_number')
            qs = Customer.objects.filter(shop=shop, mobile_number=mobile)
            if self.instance:
                qs = qs.exclude(pk=self.instance.pk)
            if qs.exists():
                raise serializers.ValidationError(
                    {'mobile_number': 'A customer with this mobile number already exists.'}
                )
        return attrs
