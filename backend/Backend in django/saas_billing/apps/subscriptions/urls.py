from django.urls import path
from . import views

urlpatterns = [
    path('plans/',           views.PlanListView.as_view(),         name='plan-list'),
    path('plans/<uuid:pk>/', views.PlanDetailView.as_view(),       name='plan-detail'),
    path('',                 views.SubscriptionView.as_view(),     name='subscription'),
    path('change-plan/',     views.ChangePlanView.as_view(),       name='change-plan'),
    path('cancel/',          views.CancelSubscriptionView.as_view(), name='cancel-subscription'),
    path('resume/',          views.ResumeSubscriptionView.as_view(), name='resume-subscription'),
    path('history/',         views.SubscriptionHistoryView.as_view(), name='subscription-history'),
    path('usage/',           views.UsageRecordListView.as_view(),  name='usage-records'),
]
