from django.urls import path
from .views import (
    PrinterListCreateView, PrinterDetailView,
    PrintReceiptView, PrintKitchenSlipView,
    PrintPreviewView, PrintJobListView,
)

urlpatterns = [
    path('printers/',                    PrinterListCreateView.as_view(), name='printer-list'),
    path('printers/<int:pk>/',           PrinterDetailView.as_view(),     name='printer-detail'),
    path('print/receipt/',               PrintReceiptView.as_view(),      name='print-receipt'),
    path('print/kitchen-slip/',          PrintKitchenSlipView.as_view(),  name='print-kitchen-slip'),
    path('preview/<int:token_id>/',      PrintPreviewView.as_view(),      name='print-preview'),
    path('jobs/',                        PrintJobListView.as_view(),       name='print-jobs'),
]
