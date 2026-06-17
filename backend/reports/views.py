from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Sum, Count, Avg, F
from django.utils import timezone
from datetime import timedelta, date

from tokens.models import Token, TokenItem
from menu.models import MenuItem, Category


class DailyReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        report_date = request.query_params.get('date', str(timezone.localdate()))
        tokens = Token.objects.filter(shop=shop, date=report_date, is_paid=True)

        agg = tokens.aggregate(
            revenue     = Sum('total'),
            subtotal    = Sum('subtotal'),
            gst         = Sum('gst_amount'),
            service     = Sum('service_charge'),
            discount    = Sum('discount'),
            count       = Count('id'),
            avg_order   = Avg('total'),
        )

        by_payment = {
            'cash': tokens.filter(payment_mode='cash').aggregate(s=Sum('total'))['s'] or 0,
            'upi':  tokens.filter(payment_mode='upi').aggregate(s=Sum('total'))['s'] or 0,
            'card': tokens.filter(payment_mode='card').aggregate(s=Sum('total'))['s'] or 0,
        }

        by_order_type = {}
        for ot in ['dine_in', 'takeaway', 'delivery']:
            by_order_type[ot] = tokens.filter(order_type=ot).aggregate(
                count=Count('id'), revenue=Sum('total')
            )

        # Dashboard requires total_bills (all time) and monthly_sales
        report_date_obj = timezone.datetime.strptime(report_date, '%Y-%m-%d').date() if isinstance(report_date, str) else report_date
        total_bills = Token.objects.filter(shop=shop).count()
        monthly_sales = Token.objects.filter(
            shop=shop,
            date__year=report_date_obj.year, 
            date__month=report_date_obj.month, 
            is_paid=True
        ).aggregate(s=Sum('total'))['s'] or 0

        return Response({
            'date':         report_date,
            'summary':      agg,
            'by_payment':   by_payment,
            'by_order_type':by_order_type,
            'total_bills':  total_bills,
            'monthly_sales':monthly_sales,
        })


class WeeklyReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        end_date   = timezone.localdate()
        start_date = end_date - timedelta(days=6)
        result = []
        d = start_date
        while d <= end_date:
            tokens = Token.objects.filter(shop=shop, date=d, is_paid=True)
            agg = tokens.aggregate(revenue=Sum('total'), count=Count('id'))
            result.append({
                'date':    str(d),
                'day':     d.strftime('%a'),
                'revenue': agg['revenue'] or 0,
                'orders':  agg['count'] or 0,
            })
            d += timedelta(days=1)
        return Response(result)


class MonthlyReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        year  = int(request.query_params.get('year',  timezone.now().year))
        month = int(request.query_params.get('month', timezone.now().month))
        tokens = Token.objects.filter(shop=shop, date__year=year, date__month=month, is_paid=True)

        agg = tokens.aggregate(
            revenue  = Sum('total'),
            count    = Count('id'),
            avg      = Avg('total'),
        )

        # Daily breakdown
        from django.db.models.functions import TruncDay
        daily = (
            tokens
            .annotate(day=TruncDay('created_at'))
            .values('day')
            .annotate(revenue=Sum('total'), orders=Count('id'))
            .order_by('day')
        )

        return Response({
            'year':    year,
            'month':   month,
            'summary': agg,
            'daily':   list(daily),
        })


class TopItemsReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        days  = int(request.query_params.get('days', 7))
        limit = int(request.query_params.get('limit', 10))
        start = timezone.localdate() - timedelta(days=days)

        top_items = (
            TokenItem.objects
            .filter(token__shop=shop, token__date__gte=start, token__is_paid=True)
            .values('name')
            .annotate(
                total_qty     = Sum('quantity'),
                total_revenue = Sum(F('price') * F('quantity')),
                order_count   = Count('token', distinct=True),
            )
            .order_by('-total_qty')[:limit]
        )

        return Response(list(top_items))


class CategoryReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        days  = int(request.query_params.get('days', 7))
        start = timezone.localdate() - timedelta(days=days)

        data = (
            TokenItem.objects
            .filter(token__shop=shop, token__date__gte=start, token__is_paid=True, menu_item__isnull=False)
            .values(category_name=F('menu_item__category__name'))
            .annotate(
                total_qty     = Sum('quantity'),
                total_revenue = Sum(F('price') * F('quantity')),
            )
            .order_by('-total_revenue')
        )

        return Response(list(data))


class DateRangeReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from shop.models import Shop
        shop = Shop.get_shop(request.user)
        start = request.query_params.get('start')
        end   = request.query_params.get('end', str(timezone.localdate()))
        if not start:
            return Response({'error': 'start date required'}, status=400)

        tokens = Token.objects.filter(shop=shop, date__range=[start, end], is_paid=True)
        agg = tokens.aggregate(
            revenue   = Sum('total'),
            count     = Count('id'),
            avg_order = Avg('total'),
            discount  = Sum('discount'),
        )
        return Response({'start': start, 'end': end, 'summary': agg})
