"""Full Application Test Suite - Fixed"""
import os, sys, io, json, django, time as _time
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_pos.settings')
django.setup()
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from django.db import connection
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()
results = {}
_ts = str(int(_time.time()))[-5:]  # unique suffix per run

def check(section, name, passed, detail=""):
    key = f"{section}::{name}"
    results[key] = {"section": section, "name": name, "passed": passed, "detail": detail}
    mark = "[PASS]" if passed else "[FAIL]"
    print(f"  {mark}  {name}" + (f" -- {detail}" if detail else ""))

# ── Setup test user ────────────────────────────────────────────────
try:
    u = User.objects.get(phone="9111111111")
except User.DoesNotExist:
    u = User.objects.create_user(phone="9111111111")
    u.account_status = "approved"; u.is_active = True; u.save()

from shop.models import Shop
shop = Shop.get_shop(u)
token = str(RefreshToken.for_user(u).access_token)
client = APIClient()
client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
unauth = APIClient()

# ────────────────────────────────────────────────────────────────────
# 1. DATABASE TABLES
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  1. DATABASE TABLES")
print("="*55)
all_tables = connection.introspection.table_names()
expected_tables = {
    "core_user": ["id","phone","name","email","shop_name","account_status","is_active","created_at"],
    "core_otp": ["id","phone","code","created_at","is_used"],
    "core_appsettings": ["id","gst_enabled","gst_percentage","service_charge","currency_symbol"],
    "core_subscriptionplan": ["id","name","price_monthly","price_yearly","is_active","trial_days"],
    "core_systemsettings": ["id","payment_upi_id","created_at","updated_at"],
    "core_subscriptionpayment": ["id","user_id","plan_id","transaction_id","status","amount_paid"],
    "shop_shop": ["id","owner_id","name","tagline","address","phone","gstin","upi_id","created_at"],
    "shop_billtemplate": ["id","shop_id","shop_name","footer_message","theme_color"],
    "menu_category": ["id","shop_id","name","icon","sort_order","is_active"],
    "menu_menuitem": ["id","shop_id","category_id","name","price","is_available","created_at"],
    "tokens_token": ["id","shop_id","token_number","bill_number","status","total","is_paid","created_at"],
    "tokens_tokenitem": ["id","token_id","menu_item_id","name","price","quantity"],
    "printer_printer": ["id","shop_id","name","connection_type","paper_size","is_default","is_active"],
    "printer_printjob": ["id","printer_id","job_type","status","created_at"],
    "customers_customer": ["id","shop_id","name","mobile_number","address","gst_number","status","created_at","updated_at"],
}
for tbl, fields in expected_tables.items():
    exists = tbl in all_tables
    check("DB Tables", f"Table: {tbl}", exists)
    if exists:
        with connection.cursor() as cur:
            desc = connection.introspection.get_table_description(cur, tbl)
        col_names = {c.name for c in desc}
        for f in fields:
            check("DB Fields", f"{tbl}.{f}", f in col_names, "found" if f in col_names else "MISSING")

# ────────────────────────────────────────────────────────────────────
# 2. AUTH APIs
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  2. AUTH APIs")
print("="*55)

r = unauth.post("/api/auth/send-otp/", {"phone": "9111111111"}, format="json")
check("Auth API", "POST /auth/send-otp/ (200)", r.status_code == 200, f"got {r.status_code}")

r = unauth.post("/api/auth/register/", {"name":"Test","phone":"9111111199","shop_name":"TestShop","password":"Test@1234"}, format="json")
check("Auth API", "POST /auth/register/ (200/400/201)", r.status_code in [200,201,400], f"got {r.status_code}")

r = unauth.post("/api/auth/login/", {"phone":"9999999999","password":"admin"}, format="json")
check("Auth API", "POST /auth/login/ returns token or error", r.status_code in [200,400,401,404], f"got {r.status_code}")

r = client.get("/api/auth/profile/")
check("Auth API", "GET /auth/profile/ (200)", r.status_code == 200, f"got {r.status_code}")

r = unauth.post("/api/auth/token/refresh/", {"refresh": "bad"}, format="json")
check("Auth API", "POST /auth/token/refresh/ endpoint exists", r.status_code in [400,401], f"got {r.status_code}")

r = unauth.get("/api/auth/profile/")
check("Auth API", "GET /auth/profile/ unauthenticated = 401", r.status_code == 401, f"got {r.status_code}")

r = unauth.get("/api/auth/plans/")
check("Auth API", "GET /auth/plans/ public (200)", r.status_code == 200, f"got {r.status_code}")

r = unauth.get("/api/auth/system-settings/")
check("Auth API", "GET /auth/system-settings/ (200)", r.status_code == 200, f"got {r.status_code}")

# ────────────────────────────────────────────────────────────────────
# 3. SHOP APIs
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  3. SHOP APIs")
print("="*55)

r = client.get("/api/shop/")
check("Shop API", "GET /shop/ (200)", r.status_code == 200, f"got {r.status_code}")
if r.status_code == 200:
    d = r.json()
    check("Shop API", "GET /shop/ has 'name' field", "name" in d)
    check("Shop API", "GET /shop/ has 'id' field", "id" in d)

r = client.patch("/api/shop/", {"tagline": "Test Tagline"}, format="json")
check("Shop API", "PATCH /shop/ (200)", r.status_code == 200, f"got {r.status_code}")

r = client.get("/api/shop/bill-template/")
check("Shop API", "GET /shop/bill-template/ (200)", r.status_code == 200, f"got {r.status_code}")

r = client.patch("/api/shop/bill-template/", {"footer_message": "Thank you!"}, format="json")
check("Shop API", "PATCH /shop/bill-template/ (200)", r.status_code == 200, f"got {r.status_code}")

r = unauth.get("/api/shop/")
check("Shop API", "GET /shop/ unauthenticated = 401", r.status_code == 401, f"got {r.status_code}")

# ────────────────────────────────────────────────────────────────────
# 4. MENU APIs
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  4. MENU APIs")
print("="*55)

from menu.models import Category, MenuItem

# Category CRUD — unique names per run to avoid unique constraint errors
cat_name = f"TestCat_{_ts}"
cat_upd  = f"UpdCat_{_ts}"
Category.objects.filter(shop=shop, name__in=[cat_name, cat_upd]).delete()

r = client.post("/api/menu/categories/", {"name": cat_name, "icon": "X", "sort_order": 99}, format="json")
check("Menu API", "POST /menu/categories/ (201)", r.status_code == 201, f"got {r.status_code}")
cat_id = r.json().get("id") if r.status_code == 201 else None

r = client.get("/api/menu/categories/")
check("Menu API", "GET /menu/categories/ (200)", r.status_code == 200, f"got {r.status_code}")

if cat_id:
    r = client.patch(f"/api/menu/categories/{cat_id}/", {"name": cat_upd}, format="json")
    check("Menu API", "PATCH /menu/categories/{id}/ (200)", r.status_code == 200, f"got {r.status_code}")

# MenuItem CRUD
item_name = f"TestItem_{_ts}"
MenuItem.objects.filter(shop=shop, name=item_name).delete()
r = client.post("/api/menu/items/", {"name": item_name, "price": "99.00", "item_type": "veg", "is_available": True}, format="json")
check("Menu API", "POST /menu/items/ (201)", r.status_code == 201, f"got {r.status_code}")
item_id = r.json().get("id") if r.status_code == 201 else None

r = client.get("/api/menu/items/")
check("Menu API", "GET /menu/items/ (200)", r.status_code == 200, f"got {r.status_code}")

if item_id:
    r = client.patch(f"/api/menu/items/{item_id}/toggle/", {"is_available": False}, format="json")
    check("Menu API", "PATCH /menu/items/{id}/toggle/ (200)", r.status_code == 200, f"got {r.status_code}")
    r = client.delete(f"/api/menu/items/{item_id}/")
    check("Menu API", "DELETE /menu/items/{id}/ (204)", r.status_code == 204, f"got {r.status_code}")

r = client.get("/api/menu/by-category/")
check("Menu API", "GET /menu/by-category/ (200)", r.status_code == 200, f"got {r.status_code}")

# ────────────────────────────────────────────────────────────────────
# 5. TOKEN APIs
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  5. TOKEN APIs")
print("="*55)

from menu.models import MenuItem as MI
test_item, _ = MI.objects.get_or_create(
    shop=shop, name="Token Test Item",
    defaults={"price": "50.00", "is_available": True}
)

r = client.get("/api/tokens/")
check("Token API", "GET /tokens/ (200)", r.status_code == 200, f"got {r.status_code}")

r = client.post("/api/tokens/create/", {
    "order_type": "takeaway",
    "customer_name": "Test Customer",
    "customer_phone": "9000009999",
    "items": [{"menu_item_id": test_item.pk, "quantity": 1}]
}, format="json")
check("Token API", "POST /tokens/create/ (201)", r.status_code == 201, f"got {r.status_code}")
if r.status_code != 201:
    # Try with correct field name
    r = client.post("/api/tokens/create/", {
        "order_type": "takeaway",
        "items": [{"menu_item": test_item.pk, "quantity": 1}]
    }, format="json")
    check("Token API", "POST /tokens/create/ retry (201)", r.status_code == 201, f"got {r.status_code}")
tok_id = r.json().get("id") if r.status_code == 201 else None

if tok_id:
    r = client.get(f"/api/tokens/{tok_id}/")
    check("Token API", "GET /tokens/{id}/ (200)", r.status_code == 200, f"got {r.status_code}")
    r = client.post(f"/api/tokens/{tok_id}/payment/", {"payment_mode": "cash"}, format="json")
    check("Token API", "POST /tokens/{id}/payment/ (200)", r.status_code == 200, f"got {r.status_code}")
    r = client.patch(f"/api/tokens/{tok_id}/cancel/", {}, format="json")
    check("Token API", "PATCH /tokens/{id}/cancel/ (200/400)", r.status_code in [200,400], f"got {r.status_code}")

r = client.get("/api/tokens/summary/today/")
check("Token API", "GET /tokens/summary/today/ (200)", r.status_code == 200, f"got {r.status_code}")

r = client.get("/api/tokens/customers/search/?q=Test")
check("Token API", "GET /tokens/customers/search/ (200)", r.status_code == 200, f"got {r.status_code}")

r = client.get("/api/tokens/kitchen/")
check("Token API", "GET /tokens/kitchen/ (200)", r.status_code == 200, f"got {r.status_code}")

# ────────────────────────────────────────────────────────────────────
# 6. REPORTS APIs
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  6. REPORTS APIs")
print("="*55)

for ep in ["daily", "weekly", "monthly", "top-items", "categories"]:
    r = client.get(f"/api/reports/{ep}/")
    check("Reports API", f"GET /reports/{ep}/ (200)", r.status_code == 200, f"got {r.status_code}")

r = client.get("/api/reports/range/?start=2025-01-01&end=2025-12-31")
check("Reports API", "GET /reports/range/ (200)", r.status_code == 200, f"got {r.status_code}")

# ────────────────────────────────────────────────────────────────────
# 7. PRINTER APIs
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  7. PRINTER APIs")
print("="*55)

from printer.models import Printer
Printer.objects.filter(shop=shop, name="Test Printer API").delete()
r = client.post("/api/printer/printers/", {
    "name": "Test Printer API", "connection_type": "wifi",
    "paper_size": "80mm", "address": "192.168.1.100"
}, format="json")
check("Printer API", "POST /printer/printers/ (201)", r.status_code == 201, f"got {r.status_code}")
pr_id = r.json().get("id") if r.status_code == 201 else None

r = client.get("/api/printer/printers/")
check("Printer API", "GET /printer/printers/ (200)", r.status_code == 200, f"got {r.status_code}")

if pr_id:
    r = client.patch(f"/api/printer/printers/{pr_id}/", {"is_active": False}, format="json")
    check("Printer API", "PATCH /printer/printers/{id}/ (200)", r.status_code == 200, f"got {r.status_code}")
    r = client.delete(f"/api/printer/printers/{pr_id}/")
    check("Printer API", "DELETE /printer/printers/{id}/ (204)", r.status_code == 204, f"got {r.status_code}")

r = client.get("/api/printer/jobs/")
check("Printer API", "GET /printer/jobs/ (200)", r.status_code == 200, f"got {r.status_code}")

# ────────────────────────────────────────────────────────────────────
# 8. CUSTOMER APIs
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  8. CUSTOMER APIs")
print("="*55)

from customers.models import Customer
Customer.objects.filter(shop=shop, mobile_number="9099099099").delete()

r = client.post("/api/customers/", {
    "name": "Full Test Customer", "mobile_number": "9099099099",
    "address": "123 Test St", "gst_number": "", "status": "active"
}, format="json")
check("Customer API", "POST /customers/ (201)", r.status_code == 201, f"got {r.status_code}")
cust_id = r.json().get("id") if r.status_code == 201 else None

r = client.get("/api/customers/")
check("Customer API", "GET /customers/ (200)", r.status_code == 200, f"got {r.status_code}")

if cust_id:
    r = client.get(f"/api/customers/{cust_id}/")
    check("Customer API", "GET /customers/{id}/ (200)", r.status_code == 200, f"got {r.status_code}")
    r = client.put(f"/api/customers/{cust_id}/", {
        "name": "Updated Customer", "mobile_number": "9099099099",
        "address": "New Address", "gst_number": "", "status": "inactive"
    }, format="json")
    check("Customer API", "PUT /customers/{id}/ (200)", r.status_code == 200, f"got {r.status_code}")
    r = client.delete(f"/api/customers/{cust_id}/")
    check("Customer API", "DELETE /customers/{id}/ (204)", r.status_code == 204, f"got {r.status_code}")

r = client.get("/api/customers/?search=Test")
check("Customer API", "GET /customers/?search= (200)", r.status_code == 200, f"got {r.status_code}")
r = client.get("/api/customers/?status=active")
check("Customer API", "GET /customers/?status=active (200)", r.status_code == 200, f"got {r.status_code}")
r = unauth.get("/api/customers/")
check("Customer API", "GET /customers/ unauthenticated = 401", r.status_code == 401, f"got {r.status_code}")

# ────────────────────────────────────────────────────────────────────
# 9. VALIDATION TESTS
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  9. VALIDATION TESTS")
print("="*55)

Customer.objects.filter(shop=shop, mobile_number__in=["9099099010","9099099011"]).delete()
r = client.post("/api/customers/", {"name":"","mobile_number":"9099099010","address":"A","gst_number":"","status":"active"}, format="json")
check("Validation", "Customer: empty name rejected (400)", r.status_code == 400)
r = client.post("/api/customers/", {"name":"AB","mobile_number":"9099099010","address":"A","gst_number":"","status":"active"}, format="json")
check("Validation", "Customer: name<3 chars rejected (400)", r.status_code == 400)
r = client.post("/api/customers/", {"name":"Valid Name","mobile_number":"123456","address":"A","gst_number":"","status":"active"}, format="json")
check("Validation", "Customer: short mobile rejected (400)", r.status_code == 400)
r = client.post("/api/customers/", {"name":"Valid Name","mobile_number":"9099099010","address":"","gst_number":"","status":"active"}, format="json")
check("Validation", "Customer: empty address rejected (400)", r.status_code == 400)
r = client.post("/api/customers/", {"name":"Valid Name","mobile_number":"9099099010","address":"Test","gst_number":"BADGST","status":"active"}, format="json")
check("Validation", "Customer: invalid GST rejected (400)", r.status_code == 400)
r = client.post("/api/customers/", {"name":"Valid Name","mobile_number":"9099099010","address":"Test","gst_number":"29AAPFU0939F1ZV","status":"active"}, format="json")
check("Validation", "Customer: valid GST accepted (201)", r.status_code == 201)
r2 = client.post("/api/customers/", {"name":"Valid Name2","mobile_number":"9099099010","address":"Test","gst_number":"","status":"active"}, format="json")
check("Validation", "Customer: duplicate mobile rejected (400)", r2.status_code == 400)

r = client.post("/api/tokens/create/", {"order_type":"takeaway","items":[]}, format="json")
check("Validation", "Token: empty items rejected (400/500)", r.status_code in [400,500], f"got {r.status_code}")

# ────────────────────────────────────────────────────────────────────
# 10. ADMIN REGISTRATION
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  10. ADMIN PANEL REGISTRATION")
print("="*55)

from django.contrib import admin as dj_admin
from customers.models import Customer as CM
from shop.models import Shop as SM
from menu.models import Category as Cat, MenuItem as MI2
from tokens.models import Token as Tok
from printer.models import Printer as Pr

for model, label in [(CM,"Customer"),(SM,"Shop"),(Cat,"Category"),(MI2,"MenuItem"),(Tok,"Token"),(Pr,"Printer")]:
    check("Admin", f"{label} registered in admin", model in dj_admin.site._registry)

admin_cls = dj_admin.site._registry.get(CM)
if admin_cls:
    has_export = 'export_as_csv' in [a.__name__ if callable(a) else a for a in (admin_cls.actions or [])]
    check("Admin", "Customer admin: export_as_csv action", has_export)
    check("Admin", "Customer admin: search_fields set", bool(getattr(admin_cls,'search_fields',None)))
    check("Admin", "Customer admin: list_filter set", bool(getattr(admin_cls,'list_filter',None)))

# ────────────────────────────────────────────────────────────────────
# 11. SECURITY TESTS
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  11. SECURITY TESTS")
print("="*55)

protected = ["/api/shop/","/api/menu/items/","/api/tokens/","/api/customers/",
             "/api/printer/printers/","/api/reports/daily/","/api/auth/profile/"]
for ep in protected:
    r = unauth.get(ep)
    check("Security", f"Unauthenticated {ep} = 401", r.status_code == 401, f"got {r.status_code}")

r = client.get("/api/customers/?search='; DROP TABLE customers_customer; --")
check("Security", "SQL injection in search param safe (200)", r.status_code == 200, f"got {r.status_code}")

# ────────────────────────────────────────────────────────────────────
# 12. FLUTTER SCREENS (Static File Check)
# ────────────────────────────────────────────────────────────────────
print("\n" + "="*55)
print("  12. FLUTTER SCREENS (Static)")
print("="*55)

screens_dir = r"d:\DharmikProject\billing application\lib\screens"
expected_screens = [
    "dashboard_screen.dart","token_generation_screen.dart","item_management_screen.dart",
    "analytics_reports_screen.dart","settings_screen.dart","shop_setup_screen.dart",
    "customer_management_screen.dart","add_customer_screen.dart","main_screen.dart",
    "password_login_screen.dart","otp_login_screen.dart","registration_screen.dart",
    "printer_setup_screen.dart","print_preview_screen.dart","payment_modes_screen.dart",
    "tax_settings_screen.dart","super_admin_dashboard_screen.dart","super_admin_main_screen.dart",
    "subscription_plans_screen.dart","subscription_payment_screen.dart",
]
for s in expected_screens:
    path = os.path.join(screens_dir, s)
    check("Flutter Screens", f"Screen file: {s}", os.path.exists(path))

# ────────────────────────────────────────────────────────────────────
# SUMMARY
# ────────────────────────────────────────────────────────────────────
sections = {}
for k, v in results.items():
    sec = v["section"]
    sections.setdefault(sec, {"passed": 0, "failed": 0, "items": []})
    if v["passed"]:
        sections[sec]["passed"] += 1
    else:
        sections[sec]["failed"] += 1
    sections[sec]["items"].append(v)

total  = len(results)
passed = sum(1 for v in results.values() if v["passed"])
failed = total - passed

print("\n" + "="*55)
print("  FINAL SUMMARY")
print("="*55)
print(f"  Total: {total}  |  Passed: {passed}  |  Failed: {failed}")
for sec, data in sections.items():
    mark = "[PASS]" if data["failed"] == 0 else "[FAIL]"
    print(f"  {mark}  {sec}: {data['passed']}/{data['passed']+data['failed']}")

with open("full_test_results.json", "w", encoding="utf-8") as f:
    json.dump({"total": total, "passed": passed, "failed": failed,
               "sections": {k: {"passed": v["passed"], "failed": v["failed"]} for k,v in sections.items()},
               "all": results}, f, indent=2, ensure_ascii=False)

print(f"\n  Results saved: full_test_results.json")
sys.exit(0 if failed == 0 else 1)
