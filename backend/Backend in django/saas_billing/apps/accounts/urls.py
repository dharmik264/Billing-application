"""
accounts/urls.py
"""
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    # Auth
    path('register/',             views.RegisterView.as_view(),             name='register'),
    path('login/',                views.LoginView.as_view(),                name='login'),
    path('logout/',               views.LogoutView.as_view(),               name='logout'),
    path('token/refresh/',        TokenRefreshView.as_view(),               name='token-refresh'),
    path('verify-email/<uuid:token>/', views.VerifyEmailView.as_view(),     name='verify-email'),
    path('me/',                   views.MeView.as_view(),                   name='me'),
    path('change-password/',      views.ChangePasswordView.as_view(),       name='change-password'),
    path('password-reset/',       views.PasswordResetRequestView.as_view(), name='password-reset'),
    path('password-reset/confirm/', views.PasswordResetConfirmView.as_view(), name='password-reset-confirm'),

    # Organisation
    path('organisation/',         views.OrganisationDetailView.as_view(),   name='organisation'),
    path('organisation/users/',   views.UserListView.as_view(),             name='org-users'),
    path('organisation/users/<uuid:pk>/', views.UserDetailView.as_view(),   name='org-user-detail'),
]
