from django.urls import path
from .views import (
    CategoryListCreateView, CategoryDetailView,
    MenuItemListCreateView, MenuItemDetailView,
    ToggleItemAvailabilityView, MenuByCategoryView,
)

urlpatterns = [
    path('categories/',          CategoryListCreateView.as_view(),    name='category-list'),
    path('categories/<int:pk>/', CategoryDetailView.as_view(),        name='category-detail'),
    path('items/',               MenuItemListCreateView.as_view(),     name='item-list'),
    path('items/<int:pk>/',      MenuItemDetailView.as_view(),         name='item-detail'),
    path('items/<int:pk>/toggle/', ToggleItemAvailabilityView.as_view(), name='item-toggle'),
    path('by-category/',         MenuByCategoryView.as_view(),         name='menu-by-category'),
]
