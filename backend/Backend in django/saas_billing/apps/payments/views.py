"""
payments/views.py
"""
import stripe
import json
from django.conf import settings
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema

from .models import PaymentMethod, Payment, Refund, WebhookEvent
from .serializers import (
    PaymentMethodSerializer, AddPaymentMethodSerializer,
    PaymentSerializer, CreatePaymentSerializer,
    RefundSerializer, CreateRefundSerializer,
)
from apps.accounts.permissions import IsBillingManager

stripe.api_key = settings.STRIPE_SECRET_KEY


class PaymentMethodListView(generics.ListAPIView):
    serializer_class   = PaymentMethodSerializer
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Payments'])
    def get_queryset(self):
        return PaymentMethod.objects.filter(organisation=self.request.user.organisation)


class AddPaymentMethodView(APIView):
    """Attach a Stripe payment method to the organisation."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Payments'], request=AddPaymentMethodSerializer)
    def post(self, request):
        serializer = AddPaymentMethodSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        org     = request.user.organisation
        pm_data = serializer.validated_data

        # Attach to Stripe customer
        stripe_pm = stripe.PaymentMethod.attach(
            pm_data['payment_method_id'],
            customer=org.stripe_customer_id,
        )

        pm = PaymentMethod.objects.create(
            organisation   = org,
            type           = stripe_pm.type,
            stripe_pm_id   = stripe_pm.id,
            is_default     = pm_data['set_default'],
            card_brand     = stripe_pm.card.brand if stripe_pm.card else '',
            card_last4     = stripe_pm.card.last4 if stripe_pm.card else '',
            card_exp_month = stripe_pm.card.exp_month if stripe_pm.card else None,
            card_exp_year  = stripe_pm.card.exp_year  if stripe_pm.card else None,
        )
        return Response(PaymentMethodSerializer(pm).data, status=status.HTTP_201_CREATED)


class RemovePaymentMethodView(APIView):
    """Detach a payment method."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Payments'])
    def delete(self, request, pk):
        pm = PaymentMethod.objects.get(pk=pk, organisation=request.user.organisation)
        if pm.stripe_pm_id:
            stripe.PaymentMethod.detach(pm.stripe_pm_id)
        pm.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class SetDefaultPaymentMethodView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Payments'])
    def post(self, request, pk):
        pm = PaymentMethod.objects.get(pk=pk, organisation=request.user.organisation)
        pm.is_default = True
        pm.save()
        return Response(PaymentMethodSerializer(pm).data)


class PaymentListView(generics.ListAPIView):
    serializer_class   = PaymentSerializer
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Payments'])
    def get_queryset(self):
        return Payment.objects.filter(organisation=self.request.user.organisation)


class CreatePaymentView(APIView):
    """Charge a payment method for an invoice."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Payments'], request=CreatePaymentSerializer)
    def post(self, request):
        serializer = CreatePaymentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        from apps.invoices.models import Invoice
        invoice = Invoice.objects.get(pk=serializer.validated_data['invoice_id'],
                                      organisation=request.user.organisation)
        pm      = PaymentMethod.objects.get(pk=serializer.validated_data['payment_method_id'],
                                            organisation=request.user.organisation)

        amount_cents = int(invoice.amount_due * 100)
        pi = stripe.PaymentIntent.create(
            amount=amount_cents,
            currency=invoice.currency.lower(),
            customer=request.user.organisation.stripe_customer_id,
            payment_method=pm.stripe_pm_id,
            confirm=True,
            description=f'Invoice #{invoice.invoice_number}',
            metadata={'invoice_id': str(invoice.id)},
        )

        payment = Payment.objects.create(
            organisation   = request.user.organisation,
            invoice        = invoice,
            payment_method = pm,
            amount         = invoice.amount_due,
            currency       = invoice.currency,
            status         = Payment.Status.SUCCEEDED if pi.status == 'succeeded' else Payment.Status.PENDING,
            stripe_pi_id   = pi.id,
            paid_at        = timezone.now() if pi.status == 'succeeded' else None,
        )
        return Response(PaymentSerializer(payment).data, status=status.HTTP_201_CREATED)


class RefundListView(generics.ListAPIView):
    serializer_class   = RefundSerializer
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Payments'])
    def get_queryset(self):
        return Refund.objects.filter(payment__organisation=self.request.user.organisation)


class CreateRefundView(APIView):
    """Issue a refund for a payment."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Payments'], request=CreateRefundSerializer)
    def post(self, request):
        serializer = CreateRefundSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payment = Payment.objects.get(pk=serializer.validated_data['payment_id'],
                                      organisation=request.user.organisation)

        amount_cents  = int(serializer.validated_data['amount'] * 100)
        stripe_refund = stripe.Refund.create(
            payment_intent=payment.stripe_pi_id,
            amount=amount_cents,
        )
        refund = Refund.objects.create(
            payment          = payment,
            amount           = serializer.validated_data['amount'],
            reason           = serializer.validated_data['reason'],
            status           = Refund.Status.SUCCEEDED,
            stripe_refund_id = stripe_refund.id,
            initiated_by     = request.user,
        )
        return Response(RefundSerializer(refund).data, status=status.HTTP_201_CREATED)


@method_decorator(csrf_exempt, name='dispatch')
class StripeWebhookView(APIView):
    """Handle incoming Stripe webhook events."""
    permission_classes = [permissions.AllowAny]

    @extend_schema(tags=['Payments'])
    def post(self, request):
        payload   = request.body
        sig_header = request.META.get('HTTP_STRIPE_SIGNATURE', '')

        try:
            event = stripe.Webhook.construct_event(
                payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
            )
        except (ValueError, stripe.error.SignatureVerificationError):
            return Response({'error': 'Invalid signature'}, status=400)

        # Idempotency check
        if WebhookEvent.objects.filter(stripe_event_id=event.id).exists():
            return Response({'status': 'already_processed'})

        log = WebhookEvent.objects.create(
            stripe_event_id=event.id,
            event_type=event.type,
            payload=event.data,
        )

        from . import webhook_handlers
        try:
            webhook_handlers.handle(event)
            log.is_processed = True
            log.processed_at = timezone.now()
        except Exception as e:
            log.error = str(e)
        finally:
            log.save()

        return Response({'status': 'ok'})
