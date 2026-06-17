from django.urls import path
from . import views

urlpatterns = [
    path('tax-rates/',                views.TaxRateListView.as_view(),       name='tax-rates'),
    path('',                          views.InvoiceListCreateView.as_view(),  name='invoice-list'),
    path('<uuid:pk>/',                views.InvoiceDetailView.as_view(),      name='invoice-detail'),
    path('<uuid:pk>/send/',           views.SendInvoiceView.as_view(),        name='invoice-send'),
    path('<uuid:pk>/pdf/',            views.DownloadInvoicePDFView.as_view(), name='invoice-pdf'),
    path('<uuid:pk>/mark-paid/',      views.MarkInvoicePaidView.as_view(),    name='invoice-mark-paid'),
    path('<uuid:pk>/void/',           views.VoidInvoiceView.as_view(),        name='invoice-void'),
    path('<uuid:pk>/activity/',       views.InvoiceActivityView.as_view(),    name='invoice-activity'),
]
