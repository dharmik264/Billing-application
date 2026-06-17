from django.urls import path
from . import views

urlpatterns = [
    path('dashboard/',             views.DashboardSummaryView.as_view(),     name='dashboard'),
    path('revenue/',               views.RevenueChartView.as_view(),         name='revenue-chart'),
    path('mrr/',                   views.MRRView.as_view(),                  name='mrr'),
    path('invoices/',              views.InvoiceSummaryView.as_view(),       name='invoice-summary'),
    path('payments/success-rate/', views.PaymentSuccessRateView.as_view(),   name='payment-success-rate'),
    path('subscriptions/',         views.SubscriptionAnalyticsView.as_view(), name='subscription-analytics'),
    path('top-customers/',         views.TopCustomersView.as_view(),         name='top-customers'),
]
