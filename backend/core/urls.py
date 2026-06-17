from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import SendOTPView, VerifyOTPView, LogoutView, ProfileView, AppSettingsView

urlpatterns = [
    path('send-otp/',    SendOTPView.as_view(),    name='send-otp'),
    path('verify-otp/',  VerifyOTPView.as_view(),  name='verify-otp'),
    path('logout/',      LogoutView.as_view(),      name='logout'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
    path('profile/',     ProfileView.as_view(),     name='profile'),
    path('settings/',    AppSettingsView.as_view(), name='app-settings'),
]
