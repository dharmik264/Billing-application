from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser

from .models import Shop
from .serializers import ShopSerializer, BillTemplateSerializer


class ShopDetailView(generics.RetrieveUpdateAPIView):
    """Get and update shop details (singleton)"""
    permission_classes = [IsAuthenticated]
    serializer_class   = ShopSerializer
    parser_classes     = [MultiPartParser, FormParser, JSONParser]

    def get_object(self):
        return Shop.get_shop(self.request.user)

class BillTemplateView(generics.RetrieveUpdateAPIView):
    """Get and update bill template details for the shop (singleton)"""
    permission_classes = [IsAuthenticated]
    serializer_class   = BillTemplateSerializer
    parser_classes     = [MultiPartParser, FormParser, JSONParser]

    def get_object(self):
        shop = Shop.get_shop(self.request.user)
        from .models import BillTemplate
        return BillTemplate.get_template(shop)
