"""
Customer Ledger Feature - Comprehensive Django TestCase
"""
import os
from decimal import Decimal
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_pos.settings')
django.setup()

from django.test import TestCase
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken
from shop.models import Shop, Domain
from customers.models import Customer, CustomerPayment
from tokens.models import Token
from django.db import connection

User = get_user_model()


class CustomerLedgerTestCase(TestCase):
    def setUp(self):
        super().setUp()
        self.user, _ = User.objects.get_or_create(
            phone="9000000001",
            defaults={"is_active": True, "account_status": "approved"}
        )
        connection.set_schema_to_public()
        self.shop = Shop.get_shop(self.user)
        Domain.objects.get_or_create(domain="testserver", defaults={"tenant": self.shop, "is_primary": True})
        connection.set_schema(self.shop.schema_name)

        self.client = APIClient()
        refresh = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {str(refresh.access_token)}")

        self.cust_a = Customer.objects.create(
            name="Test Customer A",
            mobile_number="9988776655",
            address="123 Test St",
            status="active"
        )
        self.cust_b = Customer.objects.create(
            name="Test Customer B",
            mobile_number="9988776644",
            address="456 Test Ave",
            status="active"
        )

    def test_raw_data_scenario_and_ledger(self):
        token1 = Token.objects.create(
            token_number=1,
            bill_number="0001",
            customer_name=self.cust_a.name,
            customer_phone=self.cust_a.mobile_number,
            subtotal=Decimal('30000.00'),
            total=Decimal('30000.00'),
            received_amount=Decimal('0.00'),
            balance_due=Decimal('30000.00'),
            is_paid=False,
            status='open'
        )
        token2 = Token.objects.create(
            token_number=2,
            bill_number="0002",
            customer_name=self.cust_a.name,
            customer_phone=self.cust_a.mobile_number,
            subtotal=Decimal('20000.00'),
            total=Decimal('20000.00'),
            received_amount=Decimal('0.00'),
            balance_due=Decimal('20000.00'),
            is_paid=False,
            status='open'
        )

        r = self.client.get(f"/api/customers/{self.cust_a.id}/ledger/")
        self.assertEqual(r.status_code, 200)
        data = r.json()
        summary = data.get("summary", {})
        self.assertEqual(summary.get("total_billed"), 50000.0)
        self.assertEqual(summary.get("total_paid"), 0.0)
        self.assertEqual(summary.get("net_due"), 50000.0)
        self.assertEqual(summary.get("payment_status"), "UDHAR")

        # Payment 1: ₹10,000
        r_pay1 = self.client.post(f"/api/customers/{self.cust_a.id}/pay-due/", {
            "amount": 10000.0,
            "payment_mode": "cash"
        }, format="json")
        self.assertEqual(r_pay1.status_code, 200)

        # Payment 2: ₹5,000
        r_pay2 = self.client.post(f"/api/customers/{self.cust_a.id}/pay-due/", {
            "amount": 5000.0,
            "payment_mode": "cash"
        }, format="json")
        self.assertEqual(r_pay2.status_code, 200)

        # Verify summary after Pay 1 & 2
        r = self.client.get(f"/api/customers/{self.cust_a.id}/ledger/")
        summary = r.json().get("summary", {})
        self.assertEqual(summary.get("total_billed"), 50000.0)
        self.assertEqual(summary.get("total_paid"), 15000.0)
        self.assertEqual(summary.get("net_due"), 35000.0)
        self.assertEqual(summary.get("payment_status"), "UDHAR")

        # Payment 3: ₹20,000
        r_pay3 = self.client.post(f"/api/customers/{self.cust_a.id}/pay-due/", {
            "amount": 20000.0,
            "payment_mode": "upi"
        }, format="json")
        self.assertEqual(r_pay3.status_code, 200)

        # Payment 4: ₹15,000
        r_pay4 = self.client.post(f"/api/customers/{self.cust_a.id}/pay-due/", {
            "amount": 15000.0,
            "payment_mode": "card"
        }, format="json")
        self.assertEqual(r_pay4.status_code, 200)

        # Final state check
        r = self.client.get(f"/api/customers/{self.cust_a.id}/ledger/")
        summary = r.json().get("summary", {})
        self.assertEqual(summary.get("total_billed"), 50000.0)
        self.assertEqual(summary.get("total_paid"), 50000.0)
        self.assertEqual(summary.get("net_due"), 0.0)
        self.assertEqual(summary.get("payment_status"), "PAID IN FULL")

    def test_payment_validations(self):
        # Validation for amount exceeding net due
        r_over = self.client.post(f"/api/customers/{self.cust_a.id}/pay-due/", {
            "amount": 100.0,
            "payment_mode": "cash"
        }, format="json")
        self.assertEqual(r_over.status_code, 400)
        self.assertIn("Payment cannot exceed the outstanding amount", r_over.json().get("error", ""))

        # Validation for zero or negative amount
        r_zero = self.client.post(f"/api/customers/{self.cust_a.id}/pay-due/", {
            "amount": 0,
            "payment_mode": "cash"
        }, format="json")
        self.assertEqual(r_zero.status_code, 400)

        # Validation for invalid payment mode
        r_mode = self.client.post(f"/api/customers/{self.cust_a.id}/pay-due/", {
            "amount": 10,
            "payment_mode": "invalid_mode"
        }, format="json")
        self.assertEqual(r_mode.status_code, 400)

    def test_customer_isolation(self):
        Token.objects.create(
            token_number=10,
            bill_number="0010",
            customer_name=self.cust_b.name,
            customer_phone=self.cust_b.mobile_number,
            subtotal=Decimal('12000.00'),
            total=Decimal('12000.00'),
            received_amount=Decimal('0.00'),
            balance_due=Decimal('12000.00'),
            is_paid=False,
            status='open'
        )
        r_b = self.client.get(f"/api/customers/{self.cust_b.id}/ledger/")
        summary_b = r_b.json().get("summary", {})
        self.assertEqual(summary_b.get("total_billed"), 12000.0)
        self.assertEqual(summary_b.get("total_paid"), 0.0)
        self.assertEqual(summary_b.get("net_due"), 12000.0)
