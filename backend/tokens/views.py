from rest_framework import generics, status, filters
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.db import transaction, models

from menu.models import MenuItem
from .models import Token, TokenItem
from .serializers import (
    TokenSerializer, TokenListSerializer, CreateTokenSerializer,
    UpdateTokenStatusSerializer, PaymentSerializer
)


class TokenListView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class   = TokenListSerializer
    filter_backends    = [filters.OrderingFilter]
    ordering_fields    = ['-created_at']
    ordering           = ['-created_at']

    def get_queryset(self):
        qs     = Token.objects.prefetch_related('items').all()
        status_filter = self.request.query_params.get('status')
        date   = self.request.query_params.get('date')
        today  = self.request.query_params.get('today')
        is_paid = self.request.query_params.get('is_paid')

        if status_filter:
            qs = qs.filter(status=status_filter)
        else:
            qs = qs.exclude(status='cancelled')
            
        if date:
            qs = qs.filter(date=date)
        if today == 'true':
            qs = qs.filter(date=timezone.localdate())
        if is_paid is not None:
            qs = qs.filter(is_paid=is_paid.lower() == 'true')
        return qs


import re


def normalize_phone(p):
    if not p:
        return ''
    s = str(p).strip()
    digits = re.sub(r'\D', '', s)
    if not digits:
        return ''

    # Standard Indian mobile numbers: 12 digits starting with '91', 11 digits starting with '0', or 10 digits
    if len(digits) == 12 and digits.startswith('91'):
        return digits[2:]
    if len(digits) == 11 and digits.startswith('0'):
        return digits[1:]
    if len(digits) == 10:
        return digits

    # Preserve full canonical digits for international numbers with other country codes
    # (e.g. +19876543210 -> 19876543210) so different country codes do not collapse to the same key.
    return digits


class CreateTokenView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        serializer = CreateTokenSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        raw_tn = data.get('token_number')
        token_number = None
        if raw_tn is not None:
            try:
                cleaned_tn = re.sub(r'[^0-9]', '', str(raw_tn))
                if cleaned_tn:
                    token_number = int(cleaned_tn)
            except (ValueError, TypeError):
                token_number = None

        if token_number and token_number > 0:
            if Token.objects.filter(token_number=token_number, date=timezone.localdate()).exists():
                token_number = Token.get_next_token_number()
        else:
            token_number = Token.get_next_token_number()

        bill_number = data.get('bill_number')
        if bill_number:
            if Token.objects.filter(bill_number=bill_number).exists():
                bill_number = Token.get_next_bill_number()
        else:
            bill_number = Token.get_next_bill_number()

        received_amount = data.get('received_amount', 0) or 0
        payment_mode    = data.get('payment_mode', '') or ''
        is_credit       = payment_mode.lower() == 'credit'
        # Credit bills are never fully paid; blank payment_mode defers to the
        # caller's explicit is_paid value declared by CreateTokenSerializer.
        if is_credit:
            is_paid = False
        elif payment_mode:
            is_paid = True
        else:
            is_paid = data.get('is_paid', False)

        # For non-credit tokens, if is_paid is set, calculate_totals() will auto-fill
        # received_amount = total if it is 0.

        token = Token.objects.create(
            token_number  = token_number,
            bill_number   = bill_number,
            order_type    = data.get('order_type', 'dine_in'),
            table_number  = data.get('table_number') or '',
            customer_name = data.get('customer_name') or '',
            customer_phone= data.get('customer_phone') or '',
            customer_address= data.get('customer_address') or '',
            customer_gst_number= data.get('customer_gst_number') or '',
            note          = data.get('note') or '',
            payment_mode  = payment_mode,
            is_paid       = is_paid,
            status        = 'completed' if is_paid else 'open',
            received_amount = received_amount,
            # balance_due will be set accurately after calculate_totals()
        )

        for item_data in data['items']:
            menu_item_id = item_data.get('menu_item')
            try:
                quantity = int(item_data.get('quantity', 1))
            except (ValueError, TypeError):
                quantity = 1

            menu_item = None
            if menu_item_id:
                try:
                    menu_item = MenuItem.objects.get(pk=menu_item_id)
                except (MenuItem.DoesNotExist, ValueError, TypeError):
                    menu_item = None

            name = item_data.get('name') or (menu_item.name if menu_item else 'Item')
            price_val = item_data.get('price')
            if price_val is None:
                price_val = item_data.get('rate')
            if price_val is None and menu_item:
                price_val = menu_item.price

            from decimal import Decimal
            try:
                price = Decimal(str(price_val or 0))
            except (ValueError, TypeError):
                price = Decimal('0')

            TokenItem.objects.create(
                token     = token,
                menu_item = menu_item,
                name      = name,
                price     = price,
                quantity  = quantity,
                note      = item_data.get('note', ''),
            )

        token.calculate_totals()

        # Reject received_amount that exceeds the computed bill total;
        # the real total is only known after calculate_totals().
        if not is_paid and received_amount and token.total > 0:
            from decimal import Decimal
            if Decimal(str(received_amount)) > token.total:
                token.delete()
                return Response(
                    {'received_amount': [
                        f'Received amount cannot exceed bill total '
                        f'(\u20b9{token.total}).'
                    ]},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        # ── Auto-create Customer & Record Payment Log ───────────
        try:
            from customers.models import Customer, CustomerPayment
            c_phone = normalize_phone(token.customer_phone)
            c_name = (token.customer_name or '').strip()
            cust_obj = None
            if c_phone:
                cust_obj, _ = Customer.objects.get_or_create(
                    mobile_number=c_phone,
                    defaults={
                        'name': c_name or f"Customer {c_phone}",
                        'address': token.customer_address or '',
                        'gst_number': token.customer_gst_number or '',
                        'status': 'active'
                    }
                )
                if c_name and cust_obj.name != c_name:
                    cust_obj.name = c_name
                    cust_obj.save(update_fields=['name'])
            elif c_name:
                cust_obj = Customer.objects.filter(name__iexact=c_name).first()

            paid_amt = Decimal(str(token.received_amount or 0))
            if token.is_paid and paid_amt == Decimal('0'):
                paid_amt = Decimal(str(token.total or 0))

            if cust_obj and paid_amt > Decimal('0'):
                CustomerPayment.objects.create(
                    customer=cust_obj,
                    token=token,
                    amount=paid_amt,
                    payment_mode=payment_mode or ('cash' if token.is_paid else 'due'),
                    note=f"Bill #{token.bill_number} initial payment"
                )
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning(f"Auto-create customer error: {e}")

        # ── SMS Integration (Simulated) ───────────────────────────
        try:
            shop = getattr(request, 'tenant', None)
            if token.customer_phone and shop and hasattr(shop, 'sms_credits') and shop.sms_credits > 0:
                import logging
                logger = logging.getLogger(__name__)
                # Deduct 1 credit for finalized bill SMS
                shop.sms_credits -= 1
                shop.save(update_fields=['sms_credits'])
                
                sms_body = (
                    f"Dear Customer,\n"
                    f"Your bill amount is ₹{token.total}.\n"
                    f"Thank you for shopping with us.\n"
                    f"- {shop.name}\n\n"
                    f"Thank you for your purchase.\n"
                    f"We appreciate your business and look forward to serving you again.\n"
                    f"- {shop.name}"
                )
                logger.info(f"--- SIMULATED SMS SENT TO {token.customer_phone} ---")
                logger.info(sms_body)
                logger.info("-------------------------------------------")
        except Exception as e:
            import logging
            logging.getLogger(__name__).warning(f"SMS simulation error: {e}")

        return Response(TokenSerializer(token).data, status=status.HTTP_201_CREATED)


class TokenDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class   = TokenSerializer
    
    def get_queryset(self):
        return Token.objects.prefetch_related('items').all()

    @transaction.atomic
    def put(self, request, *args, **kwargs):
        # Allow updating a token including its nested items
        token = self.get_object()
        data = request.data
        
        # Update basic token fields
        token.customer_name = data.get('customer_name', token.customer_name)
        token.customer_phone = data.get('customer_phone', token.customer_phone)
        token.customer_address = data.get('customer_address', token.customer_address)
        token.customer_gst_number = data.get('customer_gst_number', token.customer_gst_number)
        token.note = data.get('note', token.note)
        if 'payment_mode' in data:
            token.payment_mode = data['payment_mode']
        if 'is_paid' in data:
            token.is_paid = data['is_paid']
        
        token.save()

        # Update items if provided
        if 'items' in data:
            token.items.all().delete()
            for item_data in data['items']:
                menu_item_id = item_data.get('menu_item')
                try:
                    quantity = int(item_data.get('quantity', 1))
                except (ValueError, TypeError):
                    quantity = 1
                try:
                    menu_item = MenuItem.objects.get(pk=menu_item_id)
                    TokenItem.objects.create(
                        token     = token,
                        menu_item = menu_item,
                        name      = menu_item.name,
                        price     = menu_item.price,
                        quantity  = quantity,
                        note      = item_data.get('note', ''),
                    )
                except (MenuItem.DoesNotExist, ValueError, TypeError):
                    continue

        token.calculate_totals()
        return Response(TokenSerializer(token).data, status=status.HTTP_200_OK)


class UpdateTokenStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        try:
            token = Token.objects.get(pk=pk)
        except Token.DoesNotExist:
            return Response({'error': 'Token not found'}, status=status.HTTP_404_NOT_FOUND)

        serializer = UpdateTokenStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        token.status = serializer.validated_data['status']
        token.save(update_fields=['status'])
        return Response(TokenSerializer(token).data)


class AddItemToTokenView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, pk):
        try:
            token = Token.objects.get(pk=pk)
        except Token.DoesNotExist:
            return Response({'error': 'Token not found'}, status=status.HTTP_404_NOT_FOUND)

        if token.status in ['completed', 'cancelled']:
            return Response({'error': 'Cannot modify a closed token'}, status=status.HTTP_400_BAD_REQUEST)

        items_data = request.data.get('items', [])
        for item_data in items_data:
            try:
                quantity = int(item_data.get('quantity', 1))
            except (ValueError, TypeError):
                quantity = 1
            try:
                menu_item = MenuItem.objects.get(pk=item_data.get('menu_item'))
                TokenItem.objects.create(
                    token     = token,
                    menu_item = menu_item,
                    name      = menu_item.name,
                    price     = menu_item.price,
                    quantity  = quantity,
                    note      = item_data.get('note', ''),
                )
            except (MenuItem.DoesNotExist, ValueError, TypeError, KeyError):
                continue

        token.calculate_totals()
        return Response(TokenSerializer(token).data)


class ProcessPaymentView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, pk):
        try:
            token = Token.objects.select_for_update().get(pk=pk)
        except Token.DoesNotExist:
            return Response({'error': 'Token not found'}, status=status.HTTP_404_NOT_FOUND)

        if token.is_paid:
            return Response({'error': 'Token already paid'}, status=status.HTTP_400_BAD_REQUEST)

        if token.status and token.status.lower() == 'cancelled':
            return Response({'error': 'Cannot process payment for a cancelled token'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = PaymentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        update_fields = ['payment_mode', 'is_paid', 'status']

        if 'discount' in request.data:
            from decimal import Decimal
            try:
                disc = Decimal(str(serializer.validated_data.get('discount', 0)))
                token.discount = max(Decimal('0.00'), disc)
                update_fields.append('discount')
            except (ValueError, TypeError):
                pass

        raw_amount = request.data.get('amount') if 'amount' in request.data else request.data.get('received_amount')
        payment_mode = serializer.validated_data['payment_mode'].strip().lower()
        token.payment_mode = payment_mode

        if raw_amount is not None:
            from decimal import Decimal, InvalidOperation
            try:
                amt = Decimal(str(raw_amount)).quantize(Decimal('0.01'))
                if not amt.is_finite() or amt <= Decimal('0.00'):
                    raise InvalidOperation
            except (ValueError, TypeError, InvalidOperation):
                return Response({'error': 'Invalid amount'}, status=status.HTTP_400_BAD_REQUEST)

            token.calculate_totals()
            current_recv = Decimal(str(token.received_amount or 0))
            remaining_due = max(Decimal('0.00'), token.total - current_recv)
            pay_amt = min(amt, remaining_due)
            new_received = current_recv + pay_amt

            if new_received > Decimal('99999999.99'):
                return Response({'error': 'Received amount exceeds maximum limit'}, status=status.HTTP_400_BAD_REQUEST)

            token.received_amount = new_received
            update_fields.append('received_amount')

            if token.received_amount >= token.total:
                token.is_paid = True
                token.status = 'completed'
        else:
            token.is_paid = True
            token.status = 'completed'

        token.save(update_fields=list(set(update_fields)))
        token.calculate_totals()
        return Response(TokenSerializer(token).data)


class CancelTokenView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        try:
            token = Token.objects.get(pk=pk)
        except Token.DoesNotExist:
            return Response({'error': 'Token not found'}, status=status.HTTP_404_NOT_FOUND)

        token.delete()
        return Response({'message': 'Token permanently deleted'})


class KitchenView(APIView):
    """Kitchen display — open/preparing tokens for today"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        tokens = Token.objects.filter(
            date=timezone.localdate(),
            status__in=['open', 'preparing']
        ).prefetch_related('items').order_by('created_at')
        return Response(TokenSerializer(tokens, many=True).data)


class TodaySummaryView(APIView):
    """Dashboard summary for today"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.db.models import Sum, Count
        today  = timezone.localdate()
        
        # All time
        total_bills = Token.objects.exclude(status='cancelled').count()
        last_bill = Token.objects.filter(date=today).exclude(bill_number='').order_by('-created_at').first()
        last_bill_number = last_bill.bill_number if last_bill else "0"
        
        # Monthly
        start_of_month = today.replace(day=1)
        monthly_tokens = Token.objects.filter(date__gte=start_of_month).exclude(status='cancelled')
        monthly_sales = monthly_tokens.aggregate(s=Sum('total'))['s'] or 0
        
        # Today
        tokens = Token.objects.filter(date=today).exclude(status='cancelled')
        agg    = tokens.aggregate(revenue=Sum('total'), count=Count('id'))

        return Response({
            'date':          str(today),
            'total_tokens':  tokens.count(), # Today tokens
            'total_bills':   total_bills,    # All time bills
            'last_bill_number': last_bill_number,
            'monthly_sales': monthly_sales,  # Monthly sales
            'paid_tokens':   tokens.filter(is_paid=True).count(),
            'open_tokens':   tokens.filter(status__in=['open', 'preparing']).count(),
            'revenue':       agg['revenue'] or 0, # Today sales (includes all bills)
            'cash':          tokens.filter(payment_mode__iexact='cash').aggregate(s=Sum('total'))['s'] or 0,
            'upi':           tokens.filter(payment_mode__in=['online / upi', 'upi', 'online', 'ONLINE', 'UPI']).aggregate(s=Sum('total'))['s'] or 0,
            'card':          tokens.filter(payment_mode__iexact='card').aggregate(s=Sum('total'))['s'] or 0,
            'credit':        tokens.filter(payment_mode__in=['credit', 'udhar', 'due', 'CREDIT', 'UDHAR']).aggregate(s=Sum('total'))['s'] or 0,
        })

class CustomerSearchAPIView(APIView):
    """Search unique customers from past tokens for autocomplete"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.db.models import Q
        query = request.query_params.get('q', '').strip()

        qs = Token.objects.exclude(customer_name='').exclude(customer_phone='')
        
        if query:
            qs = qs.filter(Q(customer_name__icontains=query) | Q(customer_phone__icontains=query))
            
        customers = qs.values('customer_name', 'customer_phone').distinct()[:20]
        
        return Response([{
            'name': c['customer_name'],
            'phone': c['customer_phone']
        } for c in customers])


class CustomerJamaPaymentView(APIView):
    """
    POST /api/tokens/customer-jama/
    Body: { "customer_phone": "...", "amount": 500.0, "payment_mode": "cash" }
    Applies the payment towards unpaid tokens for this customer (oldest first).
    """
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        import re
        from decimal import Decimal, InvalidOperation

        customer_phone = str(request.data.get('customer_phone', '')).strip()
        customer_name  = str(request.data.get('customer_name', '')).strip()
        raw_amount     = request.data.get('amount', 0)
        payment_mode   = str(request.data.get('payment_mode', 'cash')).strip().lower()

        valid_modes = {'cash', 'upi', 'card', 'online', 'credit'}
        if payment_mode not in valid_modes:
            return Response({'error': 'Invalid payment mode'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            amount = Decimal(str(raw_amount)).quantize(Decimal('0.01'))
            if not amount.is_finite() or amount <= Decimal('0.00'):
                raise InvalidOperation
        except (ValueError, TypeError, InvalidOperation):
            return Response({'error': 'Invalid amount'}, status=status.HTTP_400_BAD_REQUEST)

        def normalize_phone(p):
            digits = re.sub(r'\D', '', str(p or ''))
            return digits[-10:] if len(digits) >= 10 else digits

        clean_phone = normalize_phone(customer_phone)

        from django.db.models import Q
        tokens = Token.objects.filter(is_paid=False).exclude(status='cancelled')
        if clean_phone:
            tokens = tokens.filter(Q(customer_phone__icontains=clean_phone) | Q(customer_phone=customer_phone))
        elif customer_name:
            tokens = tokens.filter(customer_name__iexact=customer_name)
        else:
            return Response({'error': 'customer_phone or customer_name required'}, status=status.HTTP_400_BAD_REQUEST)

        from customers.models import Customer, CustomerPayment
        req_cust = None
        if clean_phone:
            req_cust = Customer.objects.filter(mobile_number=clean_phone).first()
            if not req_cust:
                c_name = customer_name or f"Customer {clean_phone}"
                req_cust = Customer.objects.create(
                    mobile_number=clean_phone,
                    name=c_name,
                    status='active'
                )
        elif customer_name:
            cust_matches = Customer.objects.filter(name__iexact=customer_name)
            if cust_matches.exists():
                req_cust = cust_matches.first()

        tokens = tokens.order_by('created_at').select_for_update()

        remaining = amount
        updated_tokens = []

        for token in tokens:
            if clean_phone and normalize_phone(token.customer_phone) != clean_phone and token.customer_phone != customer_phone:
                continue

            token.calculate_totals()
            due = token.balance_due
            if due <= 0:
                continue

            pay_this = min(due, remaining)
            token.received_amount = Decimal(str(token.received_amount or 0)) + pay_this
            token.payment_mode = payment_mode

            if token.received_amount >= token.total:
                token.is_paid = True
                token.status = 'completed'

            token.save(update_fields=['received_amount', 'payment_mode', 'is_paid', 'status'])
            token.calculate_totals()
            updated_tokens.append(token)

            token_cust = None
            if token.customer_phone:
                t_phone = normalize_phone(token.customer_phone)
                if t_phone:
                    token_cust, _ = Customer.objects.get_or_create(
                        mobile_number=t_phone,
                        defaults={'name': token.customer_name or f"Customer {t_phone}", 'status': 'active'}
                    )
            elif token.customer_name:
                cust_matches = Customer.objects.filter(name__iexact=token.customer_name)
                if cust_matches.exists():
                    token_cust = cust_matches.first()

            target_cust = token_cust or req_cust
            if target_cust:
                CustomerPayment.objects.create(
                    customer=target_cust,
                    token=token,
                    amount=pay_this,
                    payment_mode=payment_mode,
                    note='Jama payment'
                )

            remaining -= pay_this
            if remaining <= 0:
                break

        # Handle remaining/advance payment if any unused amount remains
        if remaining > 0 and req_cust:
            CustomerPayment.objects.create(
                customer=req_cust,
                token=None,
                amount=remaining,
                payment_mode=payment_mode,
                note='Advance Jama payment'
            )

        applied_amount = amount - remaining

        return Response({
            'message': f'Successfully applied payment of \u20b9{applied_amount}',
            'amount_applied': float(applied_amount),
            'remaining_unused': float(remaining),
            'updated_tokens_count': len(updated_tokens)
        }, status=status.HTTP_200_OK)


