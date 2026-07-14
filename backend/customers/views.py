from rest_framework import generics, filters
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend

from .models import Customer
from .serializers import CustomerSerializer


def _get_shop(user):
    from shop.models import Shop
    return Shop.get_shop(user)


class CustomerListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/customers/        — list all customers for the authenticated shop
    POST /api/customers/        — create a new customer
    """
    permission_classes = [IsAuthenticated]
    serializer_class   = CustomerSerializer
    filter_backends    = [filters.SearchFilter, filters.OrderingFilter, DjangoFilterBackend]
    search_fields      = ['name', 'mobile_number', 'gst_number', 'address']
    filterset_fields   = ['status']
    ordering_fields    = ['name', 'created_at', 'updated_at']
    ordering           = ['-created_at']

    def get_queryset(self):
        return Customer.objects.filter(shop=_get_shop(self.request.user))

    def perform_create(self, serializer):
        serializer.save(shop=_get_shop(self.request.user))


class CustomerDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET    /api/customers/{id}/  — retrieve customer
    PUT    /api/customers/{id}/  — full update
    PATCH  /api/customers/{id}/  — partial update
    DELETE /api/customers/{id}/  — delete customer
    """
    permission_classes = [IsAuthenticated]
    serializer_class   = CustomerSerializer

    def get_queryset(self):
        return Customer.objects.filter(shop=_get_shop(self.request.user))
