"""
accounts/permissions.py
"""
from rest_framework.permissions import BasePermission
from .models import User


class IsAdmin(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == User.Role.ADMIN


class IsBillingManager(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.is_billing_manager
