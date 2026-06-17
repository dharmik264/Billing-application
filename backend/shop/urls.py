from django.urls import path
from .views import ShopDetailView, BillTemplateView

urlpatterns = [
    path('', ShopDetailView.as_view(), name='shop-detail'),
    path('bill-template/', BillTemplateView.as_view(), name='bill-template'),
]
