from rest_framework import serializers
from .models import Category, MenuItem


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

    class Meta:
        model  = MenuItem
        fields = ['id', 'name', 'price', 'item_type', 'is_available', 'category', 'category_name']
