from rest_framework import serializers
from .models import User, OTP, AppSettings


class SendOTPSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)

    def validate_phone(self, value):
        import re
        if not re.match(r'^\+?[0-9]{10,15}$', value):
            raise serializers.ValidationError("Enter a valid phone number.")
        return value


class RegisterSerializer(serializers.Serializer):
    name      = serializers.CharField(max_length=100)
    phone     = serializers.CharField(max_length=15)
    shop_name = serializers.CharField(max_length=200)
    email     = serializers.EmailField(required=False, allow_blank=True)

    def validate_phone(self, value):
        import re
        if not re.match(r'^\+?[0-9]{10,15}$', value):
            raise serializers.ValidationError("Enter a valid phone number.")
        return value


class VerifyOTPSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    code  = serializers.CharField(max_length=6)


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model  = User
        fields = ['id', 'phone', 'name', 'email', 'shop_name', 
                  'account_status', 'trial_end', 'approved_plan', 'permissions', 'created_at']
        read_only_fields = ['id', 'created_at']


class AppSettingsSerializer(serializers.ModelSerializer):
    class Meta:
        model  = AppSettings
        fields = '__all__'
        read_only_fields = ['id', 'created_at', 'updated_at']
