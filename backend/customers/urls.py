from django.urls import path
from .views import CustomerListCreateView, CustomerDetailView

urlpatterns = [
    path('',       CustomerListCreateView.as_view(), name='customer-list'),
    path('<int:pk>/', CustomerDetailView.as_view(),  name='customer-detail'),
]
