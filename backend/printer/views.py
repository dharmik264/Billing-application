from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .models import Printer, PrintJob
from .serializers import PrinterSerializer, PrintJobSerializer, PrintReceiptSerializer, PrintKitchenSlipSerializer
from tokens.models import Token
from shop.models import Shop
from core.models import AppSettings


def build_receipt_text(token):
    """Generate plain-text receipt content"""
    shop     = token.shop
    settings = AppSettings.get_settings(shop)
    lines    = []

    lines.append(shop.name.center(32))
    if shop.address:
        lines.append(shop.address[:32].center(32))
    if shop.phone:
        lines.append(f"Ph: {shop.phone}".center(32))
    if shop.gstin:
        lines.append(f"GSTIN: {shop.gstin}".center(32))
    lines.append('-' * 32)
    lines.append(f"Token: #{token.token_number}   {token.date}")
    if token.table_number:
        lines.append(f"Table: {token.table_number}")
    if token.customer_name:
        lines.append(f"Customer: {token.customer_name}")
    lines.append(f"Type: {token.get_order_type_display()}")
    lines.append('-' * 32)
    lines.append(f"{'Item':<18}{'Qty':>4}{'Amount':>10}")
    lines.append('-' * 32)
    for item in token.items.all():
        name = item.name[:18]
        lines.append(f"{name:<18}{item.quantity:>4}{float(item.subtotal):>10.2f}")
    lines.append('-' * 32)
    lines.append(f"{'Subtotal':>22}{float(token.subtotal):>10.2f}")
    if token.gst_amount:
        lines.append(f"{'GST':>22}{float(token.gst_amount):>10.2f}")
    if token.service_charge:
        lines.append(f"{'Service Charge':>22}{float(token.service_charge):>10.2f}")
    if token.discount:
        lines.append(f"{'Discount':>22}-{float(token.discount):>9.2f}")
    lines.append('=' * 32)
    lines.append(f"{'TOTAL':>22}{settings.currency_symbol}{float(token.total):>9.2f}")
    lines.append('=' * 32)
    lines.append(f"Payment: {token.payment_mode.upper()}")
    lines.append('')
    lines.append(settings.receipt_footer.center(32))
    return '\n'.join(lines)


def build_kitchen_slip_text(token):
    """Generate kitchen slip content"""
    lines = []
    lines.append('*** KITCHEN SLIP ***'.center(32))
    lines.append(f"Token: #{token.token_number}".center(32))
    lines.append(f"Type: {token.get_order_type_display()}")
    if token.table_number:
        lines.append(f"Table: {token.table_number}")
    lines.append(f"Time: {token.created_at.strftime('%H:%M')}")
    lines.append('-' * 32)
    for item in token.items.all():
        lines.append(f"  {item.name} x{item.quantity}")
        if item.note:
            lines.append(f"    Note: {item.note}")
    if token.note:
        lines.append('-' * 32)
        lines.append(f"Order note: {token.note}")
    lines.append('=' * 32)
    return '\n'.join(lines)


class PrinterListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class   = PrinterSerializer
    def get_queryset(self):
        from shop.models import Shop
        shop = Shop.get_shop(self.request.user)
        return Printer.objects.filter(shop=shop, is_active=True)

    def perform_create(self, serializer):
        from shop.models import Shop
        shop = Shop.get_shop(self.request.user)
        serializer.save(shop=shop)


class PrinterDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class   = PrinterSerializer
    def get_queryset(self):
        from shop.models import Shop
        shop = Shop.get_shop(self.request.user)
        return Printer.objects.filter(shop=shop)


class PrintReceiptView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = PrintReceiptSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            token = Token.objects.prefetch_related('items').get(pk=data['token_id'])
        except Token.DoesNotExist:
            return Response({'error': 'Token not found'}, status=status.HTTP_404_NOT_FOUND)

        printer = None
        if data.get('printer_id'):
            try:
                printer = Printer.objects.get(pk=data['printer_id'])
            except Printer.DoesNotExist:
                pass
        shop = token.shop
        if not printer:
            printer = Printer.objects.filter(shop=shop, is_default=True, is_active=True).first()

        content = build_receipt_text(token)
        job = PrintJob.objects.create(
            printer  = printer,
            job_type = 'receipt',
            token_id = token.pk,
            content  = content,
            status   = 'done',  # In real app: queue via Celery + ESC/POS
        )
        return Response({'job_id': job.pk, 'content': content, 'printer': PrinterSerializer(printer).data if printer else None})


class PrintKitchenSlipView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = PrintKitchenSlipSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            token = Token.objects.prefetch_related('items').get(pk=data['token_id'])
        except Token.DoesNotExist:
            return Response({'error': 'Token not found'}, status=status.HTTP_404_NOT_FOUND)

        content = build_kitchen_slip_text(token)
        job = PrintJob.objects.create(
            job_type = 'kitchen_slip',
            token_id = token.pk,
            content  = content,
            status   = 'done',
        )
        return Response({'job_id': job.pk, 'content': content})


class PrintPreviewView(APIView):
    """Preview receipt/slip without printing"""
    permission_classes = [IsAuthenticated]

    def get(self, request, token_id):
        try:
            token = Token.objects.prefetch_related('items').get(pk=token_id)
        except Token.DoesNotExist:
            return Response({'error': 'Token not found'}, status=status.HTTP_404_NOT_FOUND)

        slip_type = request.query_params.get('type', 'receipt')
        if slip_type == 'kitchen':
            content = build_kitchen_slip_text(token)
        else:
            content = build_receipt_text(token)

        return Response({'token_id': token_id, 'type': slip_type, 'content': content})


class PrintJobListView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class   = PrintJobSerializer

    def get_queryset(self):
        from shop.models import Shop
        shop = Shop.get_shop(self.request.user)
        return PrintJob.objects.filter(printer__shop=shop).select_related('printer')[:50]
