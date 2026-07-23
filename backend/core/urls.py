from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    SendOTPView, VerifyOTPView, ProfileView, AppSettingsView, LogoutView,
    RegisterView, PasswordLoginView, ShopRequestsView, ShopRequestActionView, SuperAdminStatsView,
    SuperAdminLoginView, SuperAdminUsersView, SuperAdminUpdatePermissionsView,
    SuperAdminDeleteUserView, SuperAdminSubscriptionPlanListCreateView, SuperAdminSubscriptionPlanDetailView,
    DevUsersView, DevLoginView,
    PublicSubscriptionPlanListView, SystemSettingsView, SubmitSubscriptionPaymentView, SuperAdminPaymentsView
)

urlpatterns = [
    path('send-otp/',    SendOTPView.as_view(),    name='send-otp'),
    path('verify-otp/',  VerifyOTPView.as_view(),  name='verify-otp'),
    path('register/',    RegisterView.as_view(),   name='register'),
    path('login/',       PasswordLoginView.as_view(), name='password-login'),
    path('logout/',      LogoutView.as_view(),      name='logout'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
    path('profile/',     ProfileView.as_view(),     name='profile'),
    path('settings/',    AppSettingsView.as_view(), name='app-settings'),
    path('shop-requests/', ShopRequestsView.as_view(), name='shop-requests'),
    path('shop-requests/<int:user_id>/action/', ShopRequestActionView.as_view(), name='shop-request-action'),
    path('super-admin/stats/', SuperAdminStatsView.as_view(), name='super-admin-stats'),
    path('super-admin/login/', SuperAdminLoginView.as_view(), name='super-admin-login'),
    path('super-admin/users/', SuperAdminUsersView.as_view(), name='super-admin-users'),
    path('super-admin/users/<int:user_id>/permissions/', SuperAdminUpdatePermissionsView.as_view(), name='super-admin-update-permissions'),
    path('super-admin/users/<int:user_id>/delete/', SuperAdminDeleteUserView.as_view(), name='super-admin-delete-user'),
    path('super-admin/plans/', SuperAdminSubscriptionPlanListCreateView.as_view(), name='super-admin-plans'),
    path('super-admin/plans/<int:pk>/', SuperAdminSubscriptionPlanDetailView.as_view(), name='super-admin-plan-detail'),
    path('super-admin/payments/', SuperAdminPaymentsView.as_view(), name='super-admin-payments'),
    
    # Developer Mode Endpoints
    path('dev/users/', DevUsersView.as_view(), name='dev-users'),
    path('dev/login/', DevLoginView.as_view(), name='dev-login'),
    
    # Subscription Endpoints (Public/User)
    path('plans/', PublicSubscriptionPlanListView.as_view(), name='public-plans'),
    path('system-settings/', SystemSettingsView.as_view(), name='system-settings'),
    path('subscriptions/pay/', SubmitSubscriptionPaymentView.as_view(), name='subscription-pay'),
]
