from django.urls import path
from . import views

urlpatterns = [
    path('methods/',                        views.PaymentMethodListView.as_view(),     name='payment-methods'),
    path('methods/add/',                    views.AddPaymentMethodView.as_view(),      name='add-payment-method'),
    path('methods/<uuid:pk>/remove/',       views.RemovePaymentMethodView.as_view(),   name='remove-payment-method'),
    path('methods/<uuid:pk>/set-default/',  views.SetDefaultPaymentMethodView.as_view(), name='set-default-pm'),
    path('',                                views.PaymentListView.as_view(),           name='payments'),
    path('pay/',                            views.CreatePaymentView.as_view(),         name='create-payment'),
    path('refunds/',                        views.RefundListView.as_view(),            name='refunds'),
    path('refunds/create/',                 views.CreateRefundView.as_view(),          name='create-refund'),
    path('webhook/',                        views.StripeWebhookView.as_view(),         name='stripe-webhook'),
]
