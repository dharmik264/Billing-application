"""
invoices/serializers.py
"""
from rest_framework import serializers
from .models import Invoice, LineItem, TaxRate, InvoiceActivity


class TaxRateSerializer(serializers.ModelSerializer):
    class Meta:
        model  = TaxRate
        fields = ['id', 'name', 'rate', 'country', 'is_active', 'description']


class LineItemSerializer(serializers.ModelSerializer):
    line_total   = serializers.ReadOnlyField()
    tax_amount   = serializers.ReadOnlyField()

    class Meta:
        model  = LineItem
        fields = [
            'id', 'description', 'quantity', 'unit_price', 'tax_rate',
            'discount_percent', 'sort_order', 'line_total', 'tax_amount',
        ]


class InvoiceSerializer(serializers.ModelSerializer):
    line_items = LineItemSerializer(many=True, read_only=True)

    class Meta:
        model  = Invoice
        fields = [
            'id', 'invoice_number', 'organisation', 'status', 'currency',
            'bill_to_name', 'bill_to_email', 'bill_to_address', 'bill_to_tax_id',
            'issue_date', 'due_date', 'paid_at',
            'subtotal', 'tax_amount', 'discount_amount', 'total', 'amount_paid', 'amount_due',
            'notes', 'footer', 'pdf_url',
            'line_items', 'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'invoice_number', 'subtotal', 'tax_amount', 'total',
            'amount_paid', 'amount_due', 'pdf_url', 'created_at', 'updated_at',
        ]


class CreateInvoiceSerializer(serializers.ModelSerializer):
    line_items = LineItemSerializer(many=True)

    class Meta:
        model  = Invoice
        fields = [
            'currency', 'bill_to_name', 'bill_to_email', 'bill_to_address',
            'bill_to_tax_id', 'issue_date', 'due_date', 'discount_amount',
            'notes', 'footer', 'line_items',
        ]

    def create(self, validated_data):
        line_items_data = validated_data.pop('line_items')
        invoice = Invoice.objects.create(**validated_data)
        for item_data in line_items_data:
            LineItem.objects.create(invoice=invoice, **item_data)
        invoice.calculate_totals()
        return invoice


class InvoiceActivitySerializer(serializers.ModelSerializer):
    class Meta:
        model  = InvoiceActivity
        fields = ['id', 'event', 'actor', 'note', 'created_at']
