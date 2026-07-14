"""
Customer Management Module - Comprehensive Test Script
Tests: DB table, model CRUD, API endpoints, validation, admin registration
"""
import os
import sys
import json
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_pos.settings')
django.setup()

# Fix Windows console encoding
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from django.test import TestCase, RequestFactory
from django.contrib.auth import get_user_model
from django.db import connection
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()

PASS = "[PASS]"
FAIL = "[FAIL]"
results = {}

def check(name, passed, detail=""):
    status = PASS if passed else FAIL
    results[name] = {"passed": passed, "detail": detail}
    print(f"  {status}  {name}" + (f" — {detail}" if detail else ""))

# ─── 1. DATABASE TABLE VERIFICATION ──────────────────────────────
print("\n" + "="*60)
print("  1. DATABASE TABLE VERIFICATION")
print("="*60)

# Use Django's connection introspection (works with any DB)
all_tables = connection.introspection.table_names()
table_exists = 'customers_customer' in all_tables
check("customers_customer table exists", table_exists)

if table_exists:
    with connection.cursor() as cur:
        table_desc = connection.introspection.get_table_description(cur, 'customers_customer')
    cols = {col.name for col in table_desc}
    required_fields = ["id", "name", "mobile_number", "address", "gst_number",
                       "status", "created_at", "updated_at", "shop_id"]
    for field in required_fields:
        check(f"  Column '{field}' exists", field in cols,
              f"found" if field in cols else "MISSING")

# ─── 2. MODEL CRUD TESTS ──────────────────────────────────────────
print("\n" + "="*60)
print("  2. MODEL CRUD TESTS (Direct DB)")
print("="*60)

from shop.models import Shop
from customers.models import Customer

# Get or create test shop user
try:
    test_user = User.objects.get(phone="9000000001")
except User.DoesNotExist:
    test_user = User.objects.create_user(phone="9000000001")
    test_user.is_active = True
    test_user.account_status = "approved"
    test_user.save()

try:
    test_shop = Shop.get_shop(test_user)
except Exception:
    test_shop = Shop.objects.create(owner=test_user, name="Test Shop")

# Clean old test data
Customer.objects.filter(shop=test_shop, mobile_number__in=["9876543210","9876543211"]).delete()

# CREATE
try:
    c = Customer.objects.create(
        shop=test_shop,
        name="Rajesh Kumar",
        mobile_number="9876543210",
        address="123 MG Road, Bangalore",
        gst_number="22AAAAA0000A1Z5",
        status="active",
    )
    check("CREATE: Customer record saved", c.pk is not None, f"id={c.pk}")
    check("CREATE: Name stored correctly", c.name == "Rajesh Kumar")
    check("CREATE: Mobile stored correctly", c.mobile_number == "9876543210")
    check("CREATE: Address stored correctly", c.address == "123 MG Road, Bangalore")
    check("CREATE: GST stored correctly", c.gst_number == "22AAAAA0000A1Z5")
    check("CREATE: Status stored correctly", c.status == "active")
    check("CREATE: created_at auto-set", c.created_at is not None)
    check("CREATE: updated_at auto-set", c.updated_at is not None)

    # UPDATE
    c.name = "Rajesh Kumar Updated"
    c.mobile_number = "9876543210"
    c.save()
    c.refresh_from_db()
    check("UPDATE: Name updated in DB", c.name == "Rajesh Kumar Updated")

    # DELETE
    pk = c.pk
    c.delete()
    exists_after_delete = Customer.objects.filter(pk=pk).exists()
    check("DELETE: Record removed from DB", not exists_after_delete)

except Exception as e:
    check("MODEL CRUD", False, str(e))

# ─── 3. API TESTS ─────────────────────────────────────────────────
print("\n" + "="*60)
print("  3. API ENDPOINT TESTS")
print("="*60)

client = APIClient()
refresh = RefreshToken.for_user(test_user)
client.credentials(HTTP_AUTHORIZATION=f"Bearer {str(refresh.access_token)}")

# Clean before API tests
Customer.objects.filter(shop=test_shop, mobile_number="9000000099").delete()

# POST — create
response = client.post("/api/customers/", {
    "name": "API Test Customer",
    "mobile_number": "9000000099",
    "address": "456 Test Street, Mumbai",
    "gst_number": "27AAPFU0939F1ZV",
    "status": "active",
}, format="json")

check("POST /api/customers/: Status 201", response.status_code == 201,
      f"got {response.status_code}")
created_id = None
if response.status_code == 201:
    data = response.json()
    created_id = data.get("id")
    check("POST: id returned", created_id is not None)
    check("POST: name matches", data.get("name") == "API Test Customer")
    check("POST: mobile matches", data.get("mobile_number") == "9000000099")
    check("POST: status matches", data.get("status") == "active")
    check("POST: created_at returned", "created_at" in data)
    check("POST: updated_at returned", "updated_at" in data)
else:
    check("POST: response body", False, str(response.content[:200]))

# GET list
response = client.get("/api/customers/")
check("GET /api/customers/: Status 200", response.status_code == 200,
      f"got {response.status_code}")
if response.status_code == 200:
    data = response.json()
    results_list = data.get("results", data) if isinstance(data, dict) else data
    check("GET list: returns data", len(results_list) > 0, f"count={len(results_list)}")

# GET detail
if created_id:
    response = client.get(f"/api/customers/{created_id}/")
    check("GET /api/customers/{id}/: Status 200", response.status_code == 200,
          f"got {response.status_code}")
    if response.status_code == 200:
        check("GET detail: name correct", response.json().get("name") == "API Test Customer")

# PUT — update
if created_id:
    response = client.put(f"/api/customers/{created_id}/", {
        "name": "API Test Customer Updated",
        "mobile_number": "9000000099",
        "address": "Updated Address, Pune",
        "gst_number": "",
        "status": "inactive",
    }, format="json")
    check("PUT /api/customers/{id}/: Status 200", response.status_code == 200,
          f"got {response.status_code}")
    if response.status_code == 200:
        data = response.json()
        check("PUT: name updated", data.get("name") == "API Test Customer Updated")
        check("PUT: status updated to inactive", data.get("status") == "inactive")

# DELETE
if created_id:
    response = client.delete(f"/api/customers/{created_id}/")
    check("DELETE /api/customers/{id}/: Status 204", response.status_code == 204,
          f"got {response.status_code}")
    # Confirm gone
    response2 = client.get(f"/api/customers/{created_id}/")
    check("DELETE: 404 after delete", response2.status_code == 404,
          f"got {response2.status_code}")

# GET with search
Customer.objects.filter(shop=test_shop, mobile_number="9000000088").delete()
client.post("/api/customers/", {
    "name": "Searchable Kumar",
    "mobile_number": "9000000088",
    "address": "Search Street",
    "gst_number": "",
    "status": "active",
}, format="json")
response = client.get("/api/customers/?search=Searchable")
check("GET search: Status 200", response.status_code == 200,
      f"got {response.status_code}")
if response.status_code == 200:
    data = response.json()
    results_list = data.get("results", data) if isinstance(data, dict) else data
    check("GET search: returns matching", len(results_list) > 0)

# Filter by status
response = client.get("/api/customers/?status=active")
check("GET filter by status=active: 200", response.status_code == 200)

# ─── 4. VALIDATION TESTS ──────────────────────────────────────────
print("\n" + "="*60)
print("  4. VALIDATION TESTS")
print("="*60)

def post_customer(**kwargs):
    payload = {
        "name": "Valid Name",
        "mobile_number": "9000000077",
        "address": "Valid Address",
        "gst_number": "",
        "status": "active",
    }
    payload.update(kwargs)
    return client.post("/api/customers/", payload, format="json")

# Name validations
r = post_customer(name="")
check("Validation: Empty name rejected (400)", r.status_code == 400)
r = post_customer(name="AB")
check("Validation: Name < 3 chars rejected (400)", r.status_code == 400)

# Mobile validations
r = post_customer(mobile_number="123456789")   # 9 digits
check("Validation: 9-digit mobile rejected (400)", r.status_code == 400)
r = post_customer(mobile_number="12345678901")  # 11 digits
check("Validation: 11-digit mobile rejected (400)", r.status_code == 400)
r = post_customer(mobile_number="ABCDEFGHIJ")   # non-digits
check("Validation: Non-digit mobile rejected (400)", r.status_code == 400)

# Duplicate mobile
Customer.objects.filter(shop=test_shop, mobile_number="9000000077").delete()
client.post("/api/customers/", {
    "name": "First Customer",
    "mobile_number": "9000000077",
    "address": "First Address",
    "gst_number": "",
    "status": "active",
}, format="json")
r = post_customer(name="Second Customer", mobile_number="9000000077")
check("Validation: Duplicate mobile rejected (400)", r.status_code == 400)

# GST validations
r = post_customer(mobile_number="9000000076", gst_number="INVALIDGST")
check("Validation: Invalid GST rejected (400)", r.status_code == 400)
Customer.objects.filter(shop=test_shop, mobile_number="9000000076").delete()
r = post_customer(mobile_number="9000000076", gst_number="29AAPFU0939F1ZV")
check("Validation: Valid GST accepted (201)", r.status_code == 201)

# Address validation
r = post_customer(mobile_number="9000000075", address="")
check("Validation: Empty address rejected (400)", r.status_code == 400)

# ─── 5. ADMIN REGISTRATION TESTS ──────────────────────────────────
print("\n" + "="*60)
print("  5. DJANGO ADMIN REGISTRATION")
print("="*60)

from django.contrib import admin as django_admin
from customers.models import Customer as CustomerModel
check("Admin: Customer model registered", CustomerModel in django_admin.site._registry,
      f"registered={CustomerModel in django_admin.site._registry}")

admin_class = django_admin.site._registry.get(CustomerModel)
if admin_class:
    check("Admin: search_fields configured",
          hasattr(admin_class, 'search_fields') and len(admin_class.search_fields) > 0)
    check("Admin: list_filter configured",
          hasattr(admin_class, 'list_filter') and len(admin_class.list_filter) > 0)
    check("Admin: list_display configured",
          hasattr(admin_class, 'list_display') and len(admin_class.list_display) > 0)
    check("Admin: CSV export action registered",
          'export_as_csv' in [a.__name__ if callable(a) else a
                              for a in (admin_class.actions or [])])

# ─── 6. UNAUTHENTICATED ACCESS ─────────────────────────────────────
print("\n" + "="*60)
print("  6. SECURITY: UNAUTHENTICATED ACCESS")
print("="*60)

unauth_client = APIClient()
r = unauth_client.get("/api/customers/")
check("Unauthenticated GET rejected (401)", r.status_code == 401,
      f"got {r.status_code}")
r = unauth_client.post("/api/customers/", {"name": "X"}, format="json")
check("Unauthenticated POST rejected (401)", r.status_code == 401,
      f"got {r.status_code}")

# ─── SUMMARY ──────────────────────────────────────────────────────
print("\n" + "="*60)
print("  SUMMARY")
print("="*60)
total  = len(results)
passed = sum(1 for v in results.values() if v["passed"])
failed = total - passed
print(f"\n  Total: {total}  |  Passed: {passed}  |  Failed: {failed}")
print()

failed_list = [(k, v["detail"]) for k, v in results.items() if not v["passed"]]
if failed_list:
    print("  FAILED TESTS:")
    for name, detail in failed_list:
        print(f"    {FAIL}  {name}" + (f" — {detail}" if detail else ""))
else:
    print("  ALL TESTS PASSED! 🎉")

# Export structured results for report
import json
with open("test_results.json", "w") as f:
    json.dump({"total": total, "passed": passed, "failed": failed, "tests": results}, f, indent=2)

sys.exit(0 if failed == 0 else 1)
