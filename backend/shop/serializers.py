import base64
import uuid
from django.core.files.base import ContentFile
from rest_framework import serializers
from .models import Shop

class Base64ImageField(serializers.ImageField):
    def to_internal_value(self, data):
        if isinstance(data, str):
            if data.startswith('data:image'):
                format, imgstr = data.split(';base64,') 
                ext = format.split('/')[-1] 
                data = ContentFile(base64.b64decode(imgstr), name=f'{uuid.uuid4().hex}.{ext}')
            else:
                try:
                    decoded_file = base64.b64decode(data)
                    data = ContentFile(decoded_file, name=f'{uuid.uuid4().hex}.png')
                except Exception:
                    pass
        return super().to_internal_value(data)

from .models import Shop, BillTemplate

class BillTemplateSerializer(serializers.ModelSerializer):
    logoUrl = Base64ImageField(source='logo_url', required=False, allow_null=True)
    qrCodeUrl = Base64ImageField(source='qr_code_url', required=False, allow_null=True)

    class Meta:
        model = BillTemplate
        fields = '__all__'
        read_only_fields = ['id', 'shop', 'created_at', 'updated_at']

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        request = self.context.get('request')
        if instance.logo_url and request:
            ret['logoUrl'] = request.build_absolute_uri(instance.logo_url.url)
        if instance.qr_code_url and request:
            ret['qrCodeUrl'] = request.build_absolute_uri(instance.qr_code_url.url)
        return ret

class ShopSerializer(serializers.ModelSerializer):
    logoUrl = Base64ImageField(source='logo', required=False, allow_null=True)
    qrUrl = Base64ImageField(source='qr_code', required=False, allow_null=True)
    paymentModesConfig = serializers.CharField(source='payment_modes_config', required=False)
    alternatePhone = serializers.CharField(source='alternate_phone', required=False, allow_blank=True)
    billSettings = serializers.JSONField(source='bill_settings', required=False)
    upiId = serializers.CharField(source='upi_id', required=False, allow_blank=True)
    smsCredits = serializers.IntegerField(source='sms_credits', read_only=True)

    class Meta:
        model  = Shop
        fields = ['id', 'name', 'tagline', 'address', 'phone', 'alternatePhone', 'email', 'gstin', 'fssai', 
                  'logoUrl', 'qrUrl', 'paymentModesConfig', 'opening_time', 'closing_time', 
                  'table_count', 'upiId', 'smsCredits', 'billSettings', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        request = self.context.get('request')
        if instance.logo and request:
            ret['logoUrl'] = request.build_absolute_uri(instance.logo.url)
        if instance.qr_code and request:
            ret['qrUrl'] = request.build_absolute_uri(instance.qr_code.url)
        return ret
