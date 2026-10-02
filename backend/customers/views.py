import re
from decimal import Decimal, InvalidOperation
from django.db import transaction, models
from django.db.models import Q, Sum
from rest_framework import generics, filters, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django_filters.rest_framework import DjangoFilterBackend

from tokens.models import Token
from tokens.serializers import TokenListSerializer
from .models import Customer, CustomerPayment
from .serializers import CustomerSerializer, CustomerPaymentSerializer


def normalize_phone(p):
    digits = re.sub(r'\D', '', str(p or ''))
    return digits[-10:] if len(digits) >= 10 else digits


ALLOWED_PAYMENT_MODES = {'cash', 'upi', 'card', 'online', 'net_banking', 'due', 'jama', 'other'}


def get_customer_bills(customer):
    clean_phone = normalize_phone(customer.mobile_number)
    qs = Token.objects.exclude(status='cancelled')
    if clean_phone:
        matching_ids = []
        for token_id, c_phone, c_name in qs.values_list('id', 'customer_phone', 'customer_name').iterator():
            t_phone = normalize_phone(c_phone)
            if t_phone:
                if t_phone == clean_phone:
                    matching_ids.append(token_id)
            else:
                if c_name and c_name.strip().lower() == customer.name.strip().lower():
                    matching_ids.append(token_id)
        qs = Token.objects.filter(id__in=matching_ids)
    else:
        qs = qs.filter(customer_name__iexact=customer.name)
    return qs.order_by('-created_at')


def compute_customer_ledger_summary(customer):
    bills = get_customer_bills(customer)
    total_billed = bills.aggregate(s=Sum('total'))['s'] or Decimal('0.00')

    # Sum full total for paid bills, and received_amount for unpaid bills
    paid_bills_sum = bills.filter(is_paid=True).aggregate(s=Sum('total'))['s'] or Decimal('0.00')
    unpaid_bills_recv_sum = bills.filter(is_paid=False).aggregate(s=Sum('received_amount'))['s'] or Decimal('0.00')
    bills_paid = paid_bills_sum + unpaid_bills_recv_sum

    # Advance payments not tied to any bill
    advance_paid = CustomerPayment.objects.filter(customer=customer, token__isnull=True).aggregate(s=Sum('amount'))['s'] or Decimal('0.00')

    total_paid = bills_paid + advance_paid
    net_due = max(Decimal('0.00'), total_billed - total_paid)
    payment_status = 'PAID IN FULL' if net_due == Decimal('0.00') else 'UDHAR'

    payments = CustomerPayment.objects.filter(customer=customer)

    return {
        'total_billed': total_billed,
        'total_paid': total_paid,
        'net_due': net_due,
        'payment_status': payment_status,
        'bills': bills,
        'payments': payments
    }


class CustomerListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/customers/        — list all customers for the authenticated shop
    POST /api/customers/        — create a new customer
    """
    permission_classes = [IsAuthenticated]
    serializer_class   = CustomerSerializer
    filter_backends    = [filters.SearchFilter, filters.OrderingFilter, DjangoFilterBackend]
    search_fields      = ['name', 'mobile_number', 'gst_number', 'address']
    filterset_fields   = ['status']
    ordering_fields    = ['name', 'created_at', 'updated_at']
    ordering           = ['-created_at']

    def get_queryset(self):
        return Customer.objects.all()

    def perform_create(self, serializer):
        serializer.save()


class CustomerDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET    /api/customers/{id}/  — retrieve customer
    PUT    /api/customers/{id}/  — full update
    PATCH  /api/customers/{id}/  — partial update
    DELETE /api/customers/{id}/  — delete customer
    """
    permission_classes = [IsAuthenticated]
    serializer_class   = CustomerSerializer

    def get_queryset(self):
        return Customer.objects.all()


class CustomerLedgerView(APIView):
    """
    GET /api/customers/{id}/ledger/
    Returns Customer Ledger Summary (Total Billed, Total Paid, Net Due, Status), Bills, and Payments.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, pk=None, *args, **kwargs):
        target_id = pk or kwargs.get('pk')
        customer = None

        if target_id:
            customer = Customer.objects.filter(pk=target_id).first()
            if not customer:
                phone = request.query_params.get('phone') or request.query_params.get('mobile_number')
                if phone:
                    clean_phone = normalize_phone(phone)
                    if clean_phone:
                        customer = Customer.objects.filter(mobile_number=clean_phone).first()
            if not customer:
                return Response({'error': f'Customer not found for id {target_id}.'}, status=status.HTTP_404_NOT_FOUND)
        else:
            phone = request.query_params.get('phone') or request.query_params.get('mobile_number')
            if not phone:
                return Response({'error': 'A valid customer mobile number is required.'}, status=status.HTTP_400_BAD_REQUEST)
            clean_phone = normalize_phone(phone)
            if not clean_phone:
                return Response({'error': 'A valid customer mobile number is required.'}, status=status.HTTP_400_BAD_REQUEST)
            customer = Customer.objects.filter(mobile_number=clean_phone).first()
            if not customer:
                return Response({'error': 'Customer not found'}, status=status.HTTP_404_NOT_FOUND)

        summary_data = compute_customer_ledger_summary(customer)
        
        return Response({
            'customer': CustomerSerializer(customer).data,
            'summary': {
                'total_billed': float(summary_data['total_billed']),
                'total_paid': float(summary_data['total_paid']),
                'net_due': float(summary_data['net_due']),
                'payment_status': summary_data['payment_status']
            },
            'bills': TokenListSerializer(summary_data['bills'], many=True).data,
            'payments': CustomerPaymentSerializer(summary_data['payments'], many=True).data
        })


class CustomerPayDueView(APIView):
    """
    POST /api/customers/{id}/pay-due/
    Payload: { "amount": 10000.0, "payment_mode": "cash", "note": "" }
    Validates payment and records a CustomerPayment transaction, updating open bills.
    """
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, pk=None, *args, **kwargs):
        target_id = pk or kwargs.get('pk')
        customer = None

        if target_id:
            customer = Customer.objects.select_for_update().filter(pk=target_id).first()
            if not customer:
                phone = request.data.get('phone') or request.data.get('customer_phone')
                if phone:
                    clean_phone = normalize_phone(phone)
                    if clean_phone:
                        customer = Customer.objects.select_for_update().filter(mobile_number=clean_phone).first()
            if not customer:
                return Response({'error': f'Customer not found for id {target_id}.'}, status=status.HTTP_404_NOT_FOUND)
        else:
            phone = request.data.get('phone') or request.data.get('customer_phone')
            if not phone:
                return Response({'error': 'A valid customer mobile number is required.'}, status=status.HTTP_400_BAD_REQUEST)
            clean_phone = normalize_phone(phone)
            if not clean_phone:
                return Response({'error': 'A valid customer mobile number is required.'}, status=status.HTTP_400_BAD_REQUEST)
            customer = Customer.objects.select_for_update().filter(mobile_number=clean_phone).first()
            if not customer:
                c_name = request.data.get('name') or request.data.get('customer_name') or f"Customer {clean_phone}"
                customer = Customer.objects.create(
                    mobile_number=clean_phone,
                    name=c_name,
                    status='active'
                )

        raw_amount = request.data.get('amount')
        payment_mode = str(request.data.get('payment_mode', 'cash')).strip().lower()
        note = str(request.data.get('note', '')).strip()

        if payment_mode not in ALLOWED_PAYMENT_MODES:
            return Response({'error': f'Invalid payment mode: {payment_mode}. Allowed modes: {", ".join(sorted(ALLOWED_PAYMENT_MODES))}'}, status=status.HTTP_400_BAD_REQUEST)

        if raw_amount is None:
            return Response({'error': 'Payment amount is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            amount = Decimal(str(raw_amount)).quantize(Decimal('0.01'))
            if not amount.is_finite() or amount <= Decimal('0.00'):
                return Response({'error': 'Payment amount must be greater than zero.'}, status=status.HTTP_400_BAD_REQUEST)
        except (ValueError, TypeError, InvalidOperation):
            return Response({'error': 'Invalid payment amount.'}, status=status.HTTP_400_BAD_REQUEST)

        summary_data = compute_customer_ledger_summary(customer)
        current_net_due = summary_data['net_due']

        if amount > current_net_due:
            formatted_due = f"₹{current_net_due:,.2f}".replace('.00', '')
            return Response({
                'error': f'Payment cannot exceed the outstanding amount of {formatted_due}.'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Distribute payment to unpaid tokens (oldest first)
        unpaid_tokens = get_customer_bills(customer).filter(is_paid=False).order_by('created_at').select_for_update()
        remaining_pay = amount
        payment_records = []

        for token in unpaid_tokens:
            token.calculate_totals()
            due = token.balance_due
            if due <= 0:
                continue

            pay_this = min(due, remaining_pay)
            token.received_amount = Decimal(str(token.received_amount or 0)) + pay_this
            token.payment_mode = payment_mode

            if token.received_amount >= token.total:
                token.is_paid = True
                token.status = 'completed'

            token.save(update_fields=['received_amount', 'payment_mode', 'is_paid', 'status'])
            token.calculate_totals()

            p_rec = CustomerPayment.objects.create(
                customer=customer,
                token=token,
                amount=pay_this,
                payment_mode=payment_mode,
                note=note or f"Payment for Bill #{token.bill_number}"
            )
            payment_records.append(p_rec)

            remaining_pay -= pay_this
            if remaining_pay <= 0:
                break

        if remaining_pay > 0:
            p_rec = CustomerPayment.objects.create(
                customer=customer,
                token=None,
                amount=remaining_pay,
                payment_mode=payment_mode,
                note=note or "Advance payment"
            )
            payment_records.append(p_rec)

        payment_record = payment_records[0] if payment_records else None

        # Re-compute updated summary
        updated_summary = compute_customer_ledger_summary(customer)

        formatted_amt = f"₹{amount:,.2f}".replace('.00', '')
        return Response({
            'message': f'Payment of {formatted_amt} recorded successfully.',
            'payment': CustomerPaymentSerializer(payment_record).data,
            'summary': {
                'total_billed': float(updated_summary['total_billed']),
                'total_paid': float(updated_summary['total_paid']),
                'net_due': float(updated_summary['net_due']),
                'payment_status': updated_summary['payment_status']
            },
            'bills': TokenListSerializer(updated_summary['bills'], many=True).data,
            'payments': CustomerPaymentSerializer(updated_summary['payments'], many=True).data
        }, status=status.HTTP_200_OK)
