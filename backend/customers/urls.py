from django.urls import path
from .views import (
    CustomerListCreateView, CustomerDetailView,
    CustomerLedgerView, CustomerPayDueView
)

urlpatterns = [
    path('', CustomerListCreateView.as_view(), name='customer-list'),
    path('<int:pk>/ledger/', CustomerLedgerView.as_view(), name='customer-ledger'),
    path('<int:pk>/pay-due/', CustomerPayDueView.as_view(), name='customer-pay-due'),
    path('<int:pk>/', CustomerDetailView.as_view(), name='customer-detail'),
]
