"""
accounts/views.py
"""
from django.utils import timezone
from datetime import timedelta
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView
from drf_spectacular.utils import extend_schema

from .models import User, Organisation, EmailVerificationToken, PasswordResetToken
from .serializers import (
    RegisterSerializer, LoginSerializer, UserSerializer,
    OrganisationSerializer, ChangePasswordSerializer,
    PasswordResetRequestSerializer, PasswordResetConfirmSerializer,
    UpdateProfileSerializer,
)
from .permissions import IsAdmin, IsBillingManager
from . import tasks


class RegisterView(generics.CreateAPIView):
    """Register a new user (optionally with an organisation)."""
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

    @extend_schema(tags=['Auth'])
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        tasks.send_verification_email.delay(str(user.id))
        return Response(
            {'message': 'Account created. Please verify your email.'},
            status=status.HTTP_201_CREATED
        )


class LoginView(APIView):
    """Authenticate and receive JWT tokens."""
    permission_classes = [permissions.AllowAny]

    @extend_schema(tags=['Auth'], request=LoginSerializer)
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user    = serializer.validated_data['user']
        refresh = RefreshToken.for_user(user)
        return Response({
            'access':  str(refresh.access_token),
            'refresh': str(refresh),
            'user':    UserSerializer(user).data,
        })


class LogoutView(APIView):
    """Blacklist the refresh token on logout."""

    @extend_schema(tags=['Auth'])
    def post(self, request):
        try:
            token = RefreshToken(request.data['refresh'])
            token.blacklist()
        except Exception:
            pass
        return Response({'message': 'Logged out successfully.'})


class VerifyEmailView(APIView):
    """Verify email address via token."""
    permission_classes = [permissions.AllowAny]

    @extend_schema(tags=['Auth'])
    def get(self, request, token):
        try:
            vt = EmailVerificationToken.objects.get(token=token)
        except EmailVerificationToken.DoesNotExist:
            return Response({'error': 'Invalid token.'}, status=status.HTTP_400_BAD_REQUEST)

        if not vt.is_valid():
            return Response({'error': 'Token expired.'}, status=status.HTTP_400_BAD_REQUEST)

        vt.user.is_verified = True
        vt.user.save()
        vt.is_used = True
        vt.save()
        return Response({'message': 'Email verified successfully.'})


class MeView(generics.RetrieveUpdateAPIView):
    """Get or update the current user's profile."""
    serializer_class = UserSerializer

    @extend_schema(tags=['Auth'])
    def get_object(self):
        return self.request.user

    def get_serializer_class(self):
        if self.request.method in ('PUT', 'PATCH'):
            return UpdateProfileSerializer
        return UserSerializer


class ChangePasswordView(APIView):
    """Change password for authenticated user."""

    @extend_schema(tags=['Auth'], request=ChangePasswordSerializer)
    def post(self, request):
        serializer = ChangePasswordSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        request.user.set_password(serializer.validated_data['new_password'])
        request.user.save()
        return Response({'message': 'Password changed successfully.'})


class PasswordResetRequestView(APIView):
    """Send password reset email."""
    permission_classes = [permissions.AllowAny]

    @extend_schema(tags=['Auth'], request=PasswordResetRequestSerializer)
    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            user = User.objects.get(email=serializer.validated_data['email'])
            expires = timezone.now() + timedelta(hours=2)
            token   = PasswordResetToken.objects.create(user=user, expires_at=expires)
            tasks.send_password_reset_email.delay(str(user.id), str(token.token))
        except User.DoesNotExist:
            pass  # Don't reveal whether the email exists
        return Response({'message': 'If the email exists, a reset link has been sent.'})


class PasswordResetConfirmView(APIView):
    """Confirm password reset with token."""
    permission_classes = [permissions.AllowAny]

    @extend_schema(tags=['Auth'])
    def post(self, request):
        from .serializers import PasswordResetConfirmSerializer
        serializer = PasswordResetConfirmSerializer(data=request.data, context={})
        serializer.is_valid(raise_exception=True)
        reset_token = serializer.context['reset_token']
        reset_token.user.set_password(serializer.validated_data['new_password'])
        reset_token.user.save()
        reset_token.is_used = True
        reset_token.save()
        return Response({'message': 'Password reset successful.'})


# ──────────────────────────────────────────────
# Organisation Views
# ──────────────────────────────────────────────

class OrganisationDetailView(generics.RetrieveUpdateAPIView):
    """Get or update the user's organisation."""
    serializer_class   = OrganisationSerializer
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Organisation'])
    def get_object(self):
        return self.request.user.organisation


class UserListView(generics.ListCreateAPIView):
    """List or invite users in the organisation."""
    serializer_class   = UserSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    @extend_schema(tags=['Organisation'])
    def get_queryset(self):
        return User.objects.filter(organisation=self.request.user.organisation)


class UserDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Manage a single user in the organisation."""
    serializer_class   = UserSerializer
    permission_classes = [permissions.IsAuthenticated, IsAdmin]

    @extend_schema(tags=['Organisation'])
    def get_queryset(self):
        return User.objects.filter(organisation=self.request.user.organisation)
