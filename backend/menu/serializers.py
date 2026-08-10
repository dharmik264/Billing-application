import base64
import uuid
from django.core.files.base import ContentFile
from rest_framework import serializers
from .models import Category, MenuItem


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


class CategorySerializer(serializers.ModelSerializer):
    item_count = serializers.SerializerMethodField()

    class Meta:
        model  = Category
        fields = ['id', 'name', 'icon', 'sort_order', 'is_active', 'item_count', 'created_at']
        read_only_fields = ['id', 'created_at']

    def get_item_count(self, obj):
        return obj.items.filter(is_available=True).count()


class MenuItemSerializer(serializers.ModelSerializer):
    category      = serializers.PrimaryKeyRelatedField(queryset=Category.objects.all(), required=False, allow_null=True)
    category_name = serializers.CharField(source='category.name', read_only=True)
    image         = Base64ImageField(required=False, allow_null=True)
    image_url     = serializers.SerializerMethodField()

    class Meta:
        model  = MenuItem
        fields = [
            'id', 'category', 'category_name', 'name', 'description',
            'price', 'item_type', 'image', 'image_url',
            'is_available', 'is_featured', 'sort_order', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and request:
            return request.build_absolute_uri(obj.image.url)
        return None

    def create(self, validated_data):
        category_name = self.initial_data.get('category_name')
        if category_name:
            cat, _ = Category.objects.get_or_create(name=category_name)
            validated_data['category'] = cat
        return super().create(validated_data)

    def update(self, instance, validated_data):
        category_name = self.initial_data.get('category_name')
        if category_name:
            cat, _ = Category.objects.get_or_create(name=category_name)
            validated_data['category'] = cat
        return super().update(instance, validated_data)


class MenuItemListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for listing items"""
    category_name = serializers.CharField(source='category.name', read_only=True)
    image_url     = serializers.SerializerMethodField()

    class Meta:
        model  = MenuItem
        fields = ['id', 'name', 'price', 'item_type', 'is_available', 'category', 'category_name', 'image', 'image_url']

    def get_image_url(self, obj):
        request = self.context.get('request')
        if obj.image and request:
            return request.build_absolute_uri(obj.image.url)
        return None
