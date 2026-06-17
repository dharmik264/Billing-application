from rest_framework import serializers
from .models import Printer, PrintJob


class PrinterSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Printer
        fields = '__all__'
        read_only_fields = ['id', 'created_at']


class PrintJobSerializer(serializers.ModelSerializer):
    class Meta:
        model  = PrintJob
        fields = '__all__'
        read_only_fields = ['id', 'created_at', 'status']


class PrintReceiptSerializer(serializers.Serializer):
    token_id   = serializers.IntegerField()
    printer_id = serializers.IntegerField(required=False)


class PrintKitchenSlipSerializer(serializers.Serializer):
    token_id   = serializers.IntegerField()
    printer_id = serializers.IntegerField(required=False)
