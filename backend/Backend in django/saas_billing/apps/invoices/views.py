"""
invoices/views.py
"""
import uuid
from django.utils import timezone
from django.http import HttpResponse
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django_filters.rest_framework import DjangoFilterBackend
from drf_spectacular.utils import extend_schema

from .models import Invoice, LineItem, TaxRate, InvoiceActivity
from .serializers import (
    InvoiceSerializer, CreateInvoiceSerializer,
    TaxRateSerializer, InvoiceActivitySerializer,
)
from apps.accounts.permissions import IsBillingManager
from . import pdf_service, tasks


def generate_invoice_number(org):
    count = Invoice.objects.filter(organisation=org).count() + 1
    return f'INV-{timezone.now().year}-{count:05d}'


class TaxRateListView(generics.ListCreateAPIView):
    serializer_class   = TaxRateSerializer
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]
    queryset           = TaxRate.objects.filter(is_active=True)

    @extend_schema(tags=['Invoices'])
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class InvoiceListCreateView(generics.ListCreateAPIView):
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]
    filter_backends    = [DjangoFilterBackend]
    filterset_fields   = ['status', 'currency']
    search_fields      = ['invoice_number', 'bill_to_name', 'bill_to_email']

    @extend_schema(tags=['Invoices'])
    def get_queryset(self):
        return Invoice.objects.filter(
            organisation=self.request.user.organisation
        ).prefetch_related('line_items')

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return CreateInvoiceSerializer
        return InvoiceSerializer

    def perform_create(self, serializer):
        org    = self.request.user.organisation
        number = generate_invoice_number(org)
        invoice = serializer.save(
            organisation=org,
            created_by=self.request.user,
            invoice_number=number,
        )
        InvoiceActivity.objects.create(invoice=invoice, event='created', actor=self.request.user)


class InvoiceDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Invoices'])
    def get_queryset(self):
        return Invoice.objects.filter(organisation=self.request.user.organisation)

    def get_serializer_class(self):
        if self.request.method in ('PUT', 'PATCH'):
            return CreateInvoiceSerializer
        return InvoiceSerializer

    def destroy(self, request, *args, **kwargs):
        invoice = self.get_object()
        if invoice.status not in (Invoice.Status.DRAFT,):
            return Response(
                {'error': 'Only draft invoices can be deleted.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        return super().destroy(request, *args, **kwargs)


class SendInvoiceView(APIView):
    """Send invoice to customer by email."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Invoices'])
    def post(self, request, pk):
        invoice = Invoice.objects.get(pk=pk, organisation=request.user.organisation)
        if invoice.status == Invoice.Status.DRAFT:
            invoice.status = Invoice.Status.OPEN
            invoice.save()
        tasks.send_invoice_email.delay(str(invoice.id))
        InvoiceActivity.objects.create(invoice=invoice, event='sent', actor=request.user)
        return Response({'message': 'Invoice sent successfully.'})


class DownloadInvoicePDFView(APIView):
    """Download invoice as PDF."""
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(tags=['Invoices'])
    def get(self, request, pk):
        invoice = Invoice.objects.get(pk=pk, organisation=request.user.organisation)
        pdf     = pdf_service.generate_invoice_pdf(invoice)
        response = HttpResponse(pdf, content_type='application/pdf')
        response['Content-Disposition'] = f'attachment; filename="invoice-{invoice.invoice_number}.pdf"'
        return response


class MarkInvoicePaidView(APIView):
    """Manually mark an invoice as paid."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Invoices'])
    def post(self, request, pk):
        invoice = Invoice.objects.get(pk=pk, organisation=request.user.organisation)
        invoice.status      = Invoice.Status.PAID
        invoice.paid_at     = timezone.now()
        invoice.amount_paid = invoice.total
        invoice.amount_due  = 0
        invoice.save()
        InvoiceActivity.objects.create(invoice=invoice, event='marked_paid', actor=request.user)
        return Response(InvoiceSerializer(invoice).data)


class VoidInvoiceView(APIView):
    """Void an invoice."""
    permission_classes = [permissions.IsAuthenticated, IsBillingManager]

    @extend_schema(tags=['Invoices'])
    def post(self, request, pk):
        invoice = Invoice.objects.get(pk=pk, organisation=request.user.organisation)
        if invoice.status == Invoice.Status.PAID:
            return Response({'error': 'Cannot void a paid invoice.'}, status=400)
        invoice.status = Invoice.Status.VOID
        invoice.save()
        InvoiceActivity.objects.create(invoice=invoice, event='voided', actor=request.user)
        return Response(InvoiceSerializer(invoice).data)


class InvoiceActivityView(generics.ListAPIView):
    serializer_class   = InvoiceActivitySerializer
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(tags=['Invoices'])
    def get_queryset(self):
        return InvoiceActivity.objects.filter(
            invoice__id=self.kwargs['pk'],
            invoice__organisation=self.request.user.organisation
        )
