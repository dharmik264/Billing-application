from django.urls import path
from .views import (
    TokenListView, CreateTokenView, TokenDetailView,
    UpdateTokenStatusView, AddItemToTokenView,
    ProcessPaymentView, CancelTokenView,
    KitchenView, TodaySummaryView, CustomerSearchAPIView
)

urlpatterns = [
    path('',                           TokenListView.as_view(),          name='token-list'),
    path('create/',                    CreateTokenView.as_view(),         name='token-create'),
    path('<int:pk>/',                  TokenDetailView.as_view(),         name='token-detail'),
    path('<int:pk>/status/',           UpdateTokenStatusView.as_view(),   name='token-status'),
    path('<int:pk>/add-items/',        AddItemToTokenView.as_view(),      name='token-add-items'),
    path('<int:pk>/payment/',          ProcessPaymentView.as_view(),      name='token-payment'),
    path('<int:pk>/cancel/',           CancelTokenView.as_view(),         name='token-cancel'),
    path('kitchen/',                   KitchenView.as_view(),             name='kitchen'),
    path('summary/today/',             TodaySummaryView.as_view(),        name='today-summary'),
    path('customers/search/',          CustomerSearchAPIView.as_view(),   name='customer-search'),
]
