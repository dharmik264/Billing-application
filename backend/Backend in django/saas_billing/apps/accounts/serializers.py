"""
accounts/serializers.py
"""
from django.contrib.auth import authenticate
from django.utils import timezone
from datetime import timedelta
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User, Organisation, EmailVerificationToken, PasswordResetToken


class OrganisationSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Organisation
        fields = [
            'id', 'name', 'slug', 'logo', 'address_line1', 'address_line2',
            'city', 'state', 'postal_code', 'country', 'tax_id', 'timezone',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class UserSerializer(serializers.ModelSerializer):
    organisation = OrganisationSerializer(read_only=True)
    full_name    = serializers.SerializerMethodField()

    class Meta:
        model  = User
        fields = [
            'id', 'email', 'first_name', 'last_name', 'full_name',
            'role', 'organisation', 'avatar', 'phone',
            'is_active', 'is_verified', 'date_joined',
        ]
        read_only_fields = ['id', 'is_active', 'is_verified', 'date_joined']

    def get_full_name(self, obj):
        return obj.get_full_name()


class RegisterSerializer(serializers.ModelSerializer):
    password         = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True)
    org_name         = serializers.CharField(write_only=True, required=False)

    class Meta:
        model  = User
        fields = ['email', 'first_name', 'last_name', 'password', 'confirm_password', 'org_name']

    def validate(self, data):
        if data['password'] != data['confirm_password']:
            raise serializers.ValidationError({'confirm_password': 'Passwords do not match.'})
        return data

    def create(self, validated_data):
        org_name = validated_data.pop('org_name', None)
        validated_data.pop('confirm_password')
        user = User.objects.create_user(**validated_data)

        if org_name:
            from django.utils.text import slugify
            slug = slugify(org_name)
            org  = Organisation.objects.create(name=org_name, slug=slug)
            user.organisation = org
            user.role         = User.Role.ADMIN
            user.save()

        # Create email verification token
        expires = timezone.now() + timedelta(hours=24)
        EmailVerificationToken.objects.create(user=user, expires_at=expires)
        return user


class LoginSerializer(serializers.Serializer):
    email    = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, data):
        user = authenticate(email=data['email'], password=data['password'])
        if not user:
            raise serializers.ValidationError('Invalid credentials.')
        if not user.is_active:
            raise serializers.ValidationError('Account is disabled.')
        data['user'] = user
        return data


class TokenResponseSerializer(serializers.Serializer):
    access  = serializers.CharField()
    refresh = serializers.CharField()
    user    = UserSerializer()


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)

    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError('Old password is incorrect.')
        return value


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetConfirmSerializer(serializers.Serializer):
    token        = serializers.UUIDField()
    new_password = serializers.CharField(min_length=8)

    def validate_token(self, value):
        try:
            token = PasswordResetToken.objects.get(token=value)
        except PasswordResetToken.DoesNotExist:
            raise serializers.ValidationError('Invalid token.')
        if not token.is_valid():
            raise serializers.ValidationError('Token has expired or already been used.')
        self.context['reset_token'] = token
        return value


class UpdateProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model  = User
        fields = ['first_name', 'last_name', 'phone', 'avatar']
