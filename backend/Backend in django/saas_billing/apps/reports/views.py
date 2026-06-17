"""
reports/views.py
Analytics & reporting endpoints.
"""
from django.db.models import Sum, Count, Avg, F, Q
from django.db.models.functions import TruncMonth, TruncDay
from django.utils import timezone
from datetime import timedelta
from rest_framework import permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from drf_spectacular.utils import extend_schema

from apps.invoices.models import Invoice
from apps.payments.models import Payment
from apps.subscriptions.models import Subscription
from apps.accounts.permissions import IsBillingManager


def date_filter(request):
    date_from = request.query_params.get('date_from')
    date_to   = request.query_params.get('date_to')
    if not date_from:
        date_from = (timezone.now() - timedelta(days=30)).date()
    if not date_to:
        date_to = timezone.now().date()
    return date_from, date_to


class DashboardSummaryView(APIView):
    """High-level KPIs for the dashboard."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Reports'])
    def get(self, request):
        org = request.user.organisation
        date_from, date_to = date_filter(request)

        invoices = Invoice.objects.filter(organisation=org)
        payments = Payment.objects.filter(organisation=org, status='succeeded')

        total_revenue   = payments.filter(paid_at__date__gte=date_from, paid_at__date__lte=date_to).aggregate(t=Sum('amount'))['t'] or 0
        total_invoices  = invoices.filter(created_at__date__gte=date_from).count()
        paid_invoices   = invoices.filter(status='paid', paid_at__date__gte=date_from).count()
        overdue_invoices= invoices.filter(status='past_due').count()
        outstanding_amt = invoices.filter(status__in=['open','past_due']).aggregate(t=Sum('amount_due'))['t'] or 0

        try:
            sub    = org.subscription
            plan   = sub.plan.name
            status = sub.status
        except Exception:
            plan   = None
            status = None

        return Response({
            'period':             {'from': date_from, 'to': date_to},
            'total_revenue':      float(total_revenue),
            'total_invoices':     total_invoices,
            'paid_invoices':      paid_invoices,
            'overdue_invoices':   overdue_invoices,
            'outstanding_amount': float(outstanding_amt),
            'subscription':       {'plan': plan, 'status': status},
        })


class RevenueChartView(APIView):
    """Monthly revenue grouped by month."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Reports'])
    def get(self, request):
        org = request.user.organisation
        months = int(request.query_params.get('months', 12))
        start  = timezone.now() - timedelta(days=months*30)

        data = (
            Payment.objects
            .filter(organisation=org, status='succeeded', paid_at__gte=start)
            .annotate(month=TruncMonth('paid_at'))
            .values('month')
            .annotate(revenue=Sum('amount'), count=Count('id'))
            .order_by('month')
        )
        return Response([{
            'month':   d['month'].strftime('%Y-%m'),
            'revenue': float(d['revenue']),
            'count':   d['count'],
        } for d in data])


class MRRView(APIView):
    """Monthly Recurring Revenue calculation."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Reports'])
    def get(self, request):
        active_subs = Subscription.objects.filter(
            status__in=['active', 'trialing']
        ).select_related('plan')

        mrr = sum(
            float(sub.plan.price) / (12 if sub.plan.billing_interval == 'yearly' else 1)
            for sub in active_subs
        )
        return Response({
            'mrr': round(mrr, 2),
            'arr': round(mrr * 12, 2),
            'active_subscriptions': active_subs.count(),
        })


class InvoiceSummaryView(APIView):
    """Invoice breakdown by status."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Reports'])
    def get(self, request):
        org  = request.user.organisation
        data = (
            Invoice.objects
            .filter(organisation=org)
            .values('status')
            .annotate(count=Count('id'), total=Sum('total'))
            .order_by('status')
        )
        return Response([{
            'status': d['status'],
            'count':  d['count'],
            'total':  float(d['total'] or 0),
        } for d in data])


class PaymentSuccessRateView(APIView):
    """Payment success vs failure rate."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Reports'])
    def get(self, request):
        org = request.user.organisation
        date_from, date_to = date_filter(request)
        qs  = Payment.objects.filter(
            organisation=org,
            created_at__date__gte=date_from,
            created_at__date__lte=date_to,
        )
        total     = qs.count()
        succeeded = qs.filter(status='succeeded').count()
        failed    = qs.filter(status='failed').count()
        rate      = (succeeded / total * 100) if total else 0
        return Response({
            'total':        total,
            'succeeded':    succeeded,
            'failed':       failed,
            'success_rate': round(rate, 2),
        })


class SubscriptionAnalyticsView(APIView):
    """Subscription growth and churn metrics."""
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(tags=['Reports'])
    def get(self, request):
        now    = timezone.now()
        month  = now.replace(day=1)
        active = Subscription.objects.filter(status__in=['active','trialing'])
        new_this_month    = Subscription.objects.filter(created_at__gte=month).count()
        canceled_this_month = Subscription.objects.filter(
            canceled_at__gte=month, status='canceled'
        ).count()

        plan_breakdown = (
            active.values('plan__name')
            .annotate(count=Count('id'))
            .order_by('-count')
        )
        return Response({
            'active_subscriptions':   active.count(),
            'new_this_month':         new_this_month,
            'canceled_this_month':    canceled_this_month,
            'plan_breakdown': [{
                'plan':  d['plan__name'],
                'count': d['count'],
            } for d in plan_breakdown],
        })


class TopCustomersView(APIView):
    """Top revenue-generating customers."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Reports'])
    def get(self, request):
        org = request.user.organisation
        data = (
            Payment.objects
            .filter(organisation=org, status='succeeded')
            .values('invoice__bill_to_name', 'invoice__bill_to_email')
            .annotate(total_paid=Sum('amount'), payment_count=Count('id'))
            .order_by('-total_paid')[:10]
        )
        return Response([{
            'name':          d['invoice__bill_to_name'],
            'email':         d['invoice__bill_to_email'],
            'total_paid':    float(d['total_paid']),
            'payment_count': d['payment_count'],
        } for d in data])
