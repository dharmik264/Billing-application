from django.urls import path
from .views import (
    DailyReportView, WeeklyReportView, MonthlyReportView,
    TopItemsReportView, CategoryReportView, DateRangeReportView,
)

urlpatterns = [
    path('daily/',      DailyReportView.as_view(),    name='report-daily'),
    path('weekly/',     WeeklyReportView.as_view(),   name='report-weekly'),
    path('monthly/',    MonthlyReportView.as_view(),  name='report-monthly'),
    path('top-items/',  TopItemsReportView.as_view(), name='report-top-items'),
    path('categories/', CategoryReportView.as_view(), name='report-categories'),
    path('range/',      DateRangeReportView.as_view(),name='report-range'),
]
