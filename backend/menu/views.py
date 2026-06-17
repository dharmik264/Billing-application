from rest_framework import generics, status, filters
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django_filters.rest_framework import DjangoFilterBackend

from .models import Category, MenuItem
from .serializers import CategorySerializer, MenuItemSerializer, MenuItemListSerializer


class CategoryListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class   = CategorySerializer
    def get_queryset(self):
        from shop.models import Shop
        return Category.objects.filter(shop=Shop.get_shop(self.request.user))
        
    def perform_create(self, serializer):
        from shop.models import Shop
        serializer.save(shop=Shop.get_shop(self.request.user))

class CategoryDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class   = CategorySerializer
    def get_queryset(self):
        from shop.models import Shop
        return Category.objects.filter(shop=Shop.get_shop(self.request.user))

class MenuItemListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    parser_classes     = [MultiPartParser, FormParser, JSONParser]
    filter_backends    = [filters.SearchFilter, filters.OrderingFilter]
    search_fields      = ['name', 'description']
    ordering_fields    = ['name', 'price', 'sort_order', 'created_at']

    def get_queryset(self):
        from shop.models import Shop
        qs = MenuItem.objects.select_related('category').filter(shop=Shop.get_shop(self.request.user))
        category = self.request.query_params.get('category')
        available = self.request.query_params.get('available')
        item_type = self.request.query_params.get('type')
        if category:
            qs = qs.filter(category_id=category)
        if available is not None:
            qs = qs.filter(is_available=available.lower() == 'true')
        if item_type:
            qs = qs.filter(item_type=item_type)
        return qs

    def get_serializer_class(self):
        if self.request.method == 'GET':
            return MenuItemListSerializer
        return MenuItemSerializer

    def perform_create(self, serializer):
        from shop.models import Shop
        serializer.save(shop=Shop.get_shop(self.request.user))

class MenuItemDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class   = MenuItemSerializer
    parser_classes     = [MultiPartParser, FormParser, JSONParser]
    
    def get_queryset(self):
        from shop.models import Shop
        return MenuItem.objects.select_related('category').filter(shop=Shop.get_shop(self.request.user))


class ToggleItemAvailabilityView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        try:
            item = MenuItem.objects.get(pk=pk, shop=shop)
        except MenuItem.DoesNotExist:
            return Response({'error': 'Item not found'}, status=status.HTTP_404_NOT_FOUND)
        item.is_available = not item.is_available
        item.save(update_fields=['is_available'])
        return Response({'id': item.pk, 'is_available': item.is_available})


class MenuByCategoryView(APIView):
    """Full menu grouped by category — used for token generation screen"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        categories = Category.objects.filter(shop=shop, is_active=True).prefetch_related('items')
        result = []
        for cat in categories:
            items = cat.items.filter(is_available=True)
            result.append({
                'id':    cat.id,
                'name':  cat.name,
                'icon':  cat.icon,
                'items': MenuItemListSerializer(items, many=True, context={'request': request}).data,
            })
        return Response(result)
