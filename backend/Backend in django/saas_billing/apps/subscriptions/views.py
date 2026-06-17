"""
subscriptions/views.py
"""
from rest_framework import generics, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema

from .models import Plan, Subscription, SubscriptionHistory, UsageRecord
from .serializers import (
    PlanSerializer, SubscriptionSerializer, ChangePlanSerializer,
    SubscriptionHistorySerializer, UsageRecordSerializer,
)
from apps.accounts.permissions import IsBillingManager
from . import stripe_service


class PlanListView(generics.ListAPIView):
    """List all active, public plans."""
    serializer_class   = PlanSerializer
    permission_classes = [permissions.AllowAny]
    queryset           = Plan.objects.filter(is_active=True, is_public=True).prefetch_related('features')

    @extend_schema(tags=['Plans'])
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class PlanDetailView(generics.RetrieveAPIView):
    serializer_class   = PlanSerializer
    permission_classes = [permissions.AllowAny]
    queryset           = Plan.objects.filter(is_active=True)

    @extend_schema(tags=['Plans'])
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class SubscriptionView(APIView):
    """Get current subscription or create one."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Subscriptions'])
    def get(self, request):
        try:
            sub = request.user.organisation.subscription
        except Subscription.DoesNotExist:
            return Response({'detail': 'No active subscription.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(SubscriptionSerializer(sub).data)

    @extend_schema(tags=['Subscriptions'], request=ChangePlanSerializer)
    def post(self, request):
        """Subscribe to a plan."""
        serializer = ChangePlanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        plan = Plan.objects.get(id=serializer.validated_data['plan_id'])
        sub  = stripe_service.create_subscription(request.user.organisation, plan)
        return Response(SubscriptionSerializer(sub).data, status=status.HTTP_201_CREATED)


class ChangePlanView(APIView):
    """Upgrade or downgrade the subscription plan."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Subscriptions'], request=ChangePlanSerializer)
    def post(self, request):
        serializer = ChangePlanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        plan = Plan.objects.get(id=serializer.validated_data['plan_id'])
        sub  = stripe_service.change_plan(
            request.user.organisation.subscription, plan,
            prorate=serializer.validated_data['prorate']
        )
        return Response(SubscriptionSerializer(sub).data)


class CancelSubscriptionView(APIView):
    """Cancel subscription (at period end)."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Subscriptions'])
    def post(self, request):
        sub = request.user.organisation.subscription
        sub = stripe_service.cancel_subscription(sub)
        return Response(SubscriptionSerializer(sub).data)


class ResumeSubscriptionView(APIView):
    """Resume a canceled subscription."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Subscriptions'])
    def post(self, request):
        sub = request.user.organisation.subscription
        sub = stripe_service.resume_subscription(sub)
        return Response(SubscriptionSerializer(sub).data)


class SubscriptionHistoryView(generics.ListAPIView):
    serializer_class   = SubscriptionHistorySerializer
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Subscriptions'])
    def get_queryset(self):
        return SubscriptionHistory.objects.filter(
            subscription=self.request.user.organisation.subscription
        )


class UsageRecordListView(generics.ListAPIView):
    serializer_class   = UsageRecordSerializer
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Subscriptions'])
    def get_queryset(self):
        return UsageRecord.objects.filter(
            subscription=self.request.user.organisation.subscription
        )
