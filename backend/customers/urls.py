from django.urls import path
from .views import (
    CustomerListCreateView, CustomerDetailView,
    CustomerLedgerView, CustomerPayDueView,
    CustomerCreditView, CustomerDebitView,
)

urlpatterns = [
    path('', CustomerListCreateView.as_view(), name='customer-list'),
    path('<int:pk>/ledger/', CustomerLedgerView.as_view(), name='customer-ledger'),
    path('<int:pk>/pay-due/', CustomerPayDueView.as_view(), name='customer-pay-due'),
    path('<int:pk>/credit/', CustomerCreditView.as_view(), name='customer-credit'),
    path('<int:pk>/debit/', CustomerDebitView.as_view(), name='customer-debit'),
    path('<int:pk>/', CustomerDetailView.as_view(), name='customer-detail'),
]

