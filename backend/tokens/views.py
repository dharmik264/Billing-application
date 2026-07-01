from rest_framework import generics, status, filters
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.db import transaction

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

    def get_queryset(self):
        from shop.models import Shop
        shop = Shop.get_shop(self.request.user)
        qs     = Token.objects.filter(shop=shop).prefetch_related('items')
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


class CreateTokenView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        serializer = CreateTokenSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        token_number = data.get('token_number')
        from shop.models import Shop
        shop = Shop.get_shop(request.user)

        if token_number:
            if Token.objects.filter(shop=shop, token_number=token_number, date=timezone.localdate()).exists():
                token_number = Token.get_next_token_number(shop)
        else:
            token_number = Token.get_next_token_number(shop)

        token = Token.objects.create(
            shop          = shop,
            token_number  = token_number,
            bill_number   = data.get('bill_number', ''),
            order_type    = data.get('order_type', 'dine_in'),
            table_number  = data.get('table_number', ''),
            customer_name = data.get('customer_name', ''),
            customer_phone= data.get('customer_phone', ''),
            note          = data.get('note', ''),
            payment_mode  = data.get('payment_mode', 'CASH'),
            is_paid       = True if data.get('payment_mode') else data.get('is_paid', False),
            status        = 'completed' if data.get('payment_mode') else 'open',
        )

        for item_data in data['items']:
            menu_item_id = item_data.get('menu_item')
            quantity     = int(item_data.get('quantity', 1))
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
            except MenuItem.DoesNotExist:
                continue

        token.calculate_totals()
        return Response(TokenSerializer(token).data, status=status.HTTP_201_CREATED)


class TokenDetailView(generics.RetrieveAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class   = TokenSerializer
    def get_queryset(self):
        from shop.models import Shop
        shop = Shop.get_shop(self.request.user)
        return Token.objects.filter(shop=shop).prefetch_related('items')


class UpdateTokenStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        try:
            token = Token.objects.get(pk=pk, shop=shop)
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
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        try:
            token = Token.objects.get(pk=pk, shop=shop)
        except Token.DoesNotExist:
            return Response({'error': 'Token not found'}, status=status.HTTP_404_NOT_FOUND)

        if token.status in ['completed', 'cancelled']:
            return Response({'error': 'Cannot modify a closed token'}, status=status.HTTP_400_BAD_REQUEST)

        items_data = request.data.get('items', [])
        for item_data in items_data:
            try:
                menu_item = MenuItem.objects.get(pk=item_data['menu_item'])
                TokenItem.objects.create(
                    token     = token,
                    menu_item = menu_item,
                    name      = menu_item.name,
                    price     = menu_item.price,
                    quantity  = item_data.get('quantity', 1),
                    note      = item_data.get('note', ''),
                )
            except MenuItem.DoesNotExist:
                continue

        token.calculate_totals()
        return Response(TokenSerializer(token).data)


class ProcessPaymentView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, pk):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        try:
            token = Token.objects.get(pk=pk, shop=shop)
        except Token.DoesNotExist:
            return Response({'error': 'Token not found'}, status=status.HTTP_404_NOT_FOUND)

        if token.is_paid:
            return Response({'error': 'Token already paid'}, status=status.HTTP_400_BAD_REQUEST)

        serializer = PaymentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        token.payment_mode = serializer.validated_data['payment_mode']
        token.discount     = serializer.validated_data.get('discount', 0)
        token.is_paid      = True
        token.status       = 'completed'
        token.save(update_fields=['payment_mode', 'discount', 'is_paid', 'status'])
        token.calculate_totals()

        return Response(TokenSerializer(token).data)


class CancelTokenView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        try:
            token = Token.objects.get(pk=pk, shop=shop)
        except Token.DoesNotExist:
            return Response({'error': 'Token not found'}, status=status.HTTP_404_NOT_FOUND)

        token.delete()
        return Response({'message': 'Token permanently deleted'})


class KitchenView(APIView):
    """Kitchen display — open/preparing tokens for today"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        tokens = Token.objects.filter(
            shop=shop,
            date=timezone.localdate(),
            status__in=['open', 'preparing']
        ).prefetch_related('items').order_by('created_at')
        return Response(TokenSerializer(tokens, many=True).data)


class TodaySummaryView(APIView):
    """Dashboard summary for today"""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.db.models import Sum, Count
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        today  = timezone.localdate()
        
        # All time
        total_bills = Token.objects.filter(shop=shop).exclude(status='cancelled').count()
        
        # Monthly
        start_of_month = today.replace(day=1)
        monthly_paid = Token.objects.filter(shop=shop, date__gte=start_of_month, is_paid=True).exclude(status='cancelled')
        monthly_sales = monthly_paid.aggregate(s=Sum('total'))['s'] or 0
        
        # Today
        tokens = Token.objects.filter(shop=shop, date=today).exclude(status='cancelled')
        paid   = tokens.filter(is_paid=True)
        agg    = paid.aggregate(revenue=Sum('total'), count=Count('id'))

        return Response({
            'date':          str(today),
            'total_tokens':  tokens.count(), # Today tokens
            'total_bills':   total_bills,    # All time bills
            'monthly_sales': monthly_sales,  # Monthly sales
            'paid_tokens':   paid.count(),
            'open_tokens':   tokens.filter(status__in=['open', 'preparing']).count(),
            'revenue':       agg['revenue'] or 0, # Today sales
            'cash':          paid.filter(payment_mode__iexact='cash').aggregate(s=Sum('total'))['s'] or 0,
            'upi':           paid.filter(payment_mode__in=['online / upi', 'upi', 'online']).aggregate(s=Sum('total'))['s'] or 0,
            'card':          paid.filter(payment_mode__iexact='card').aggregate(s=Sum('total'))['s'] or 0,
        })
