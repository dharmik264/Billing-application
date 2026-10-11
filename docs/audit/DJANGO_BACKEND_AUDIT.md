# Comprehensive Django Backend Audit Report

**Audit Date:** October 2026  
**Auditor:** Principal Python/Django Backend Architect & API Security Lead  
**Scope:** Architecture, App Structure, Viewsets/APIViews, Business Logic, Reporting Mathematics, Multi-Tenancy Middleware, Serializers, and Authentication  
**Backend Stack:** Django 5.x, Django REST Framework 3.15, `django-tenants 3.7.0`, `djangorestframework-simplejwt 5.3.1`, Gunicorn, Celery, Redis

---

## 1. Backend Architecture Overview

The backend is built as a multi-tenant Point-of-Sale and accounting API engine powered by `django-tenants`.
```
backend/
├── core/            # Authentication, User model (shared), Superadmin APIs, Dev backdoors
├── shop/            # Shop & Domain models (shared), BillTemplate model
├── menu/            # Categories & Menu Items (tenant schema)
├── tokens/          # Tokens, Bills, Token Items, Orders, KOT (tenant schema)
├── customers/       # Customer profile, CustomerPayment ledger transactions (tenant schema)
├── reports/         # Analytical aggregate queries: Daily, Weekly, Monthly, Range (tenant schema)
├── printer/         # Hardware printer configurations & print job tracking (tenant schema)
└── restaurant_pos/  # Django project settings, ASGI/WSGI, tenant middleware, router
```

---

## 2. API Endpoint Inventory & Permission Audit

### 2.1 Core & Auth Endpoints (`backend/core/urls.py`)
| Endpoint | Method | View Class | Permission | Observations & Defects | Severity |
| :--- | :---: | :--- | :--- | :--- | :---: |
| `/api/auth/send-otp/` | `POST` | `SendOTPView` | `AllowAny` | In `DEBUG=True`, returns OTP directly in JSON response (`{"otp": "123456"}`). | **P0** |
| `/api/auth/verify-otp/` | `POST` | `VerifyOTPView` | `AllowAny` | Returns JWT Access & Refresh token pair on valid 6-digit OTP code. | **Good** |
| `/api/auth/register/` | `POST` | `RegisterView` | `AllowAny` | Creates User and pending Shop. In `DEBUG=True`, returns OTP in response. | **P0** |
| `/api/auth/login/` | `POST` | `PasswordLoginView` | `AllowAny` | Authenticates via phone + password; validates user account approval. | **Good** |
| `/api/auth/logout/` | `POST` | `LogoutView` | `IsAuthenticated` | Blacklists refresh token if token blacklisting is enabled. | **Good** |
| `/api/auth/token/refresh/` | `POST` | `TokenRefreshView` | `AllowAny` | SimpleJWT standard token refresh endpoint. | **Good** |
| `/api/auth/profile/` | `GET/PUT` | `ProfileView` | `IsAuthenticated` | Returns/updates user profile and associated shop schema name. | **Good** |
| `/api/auth/dev/users/` | `GET` | `DevUsersView` | `AllowAny` | **CRITICAL BACKDOOR:** Lists all users, including superusers, without authentication. | **P0** |
| `/api/auth/dev/login/` | `POST` | `DevLoginView` | `AllowAny` | **CRITICAL BACKDOOR:** Bypasses passwords and logs into ANY account simply by passing phone number. | **P0** |
| `/api/auth/super-admin/*` | Multi | SuperAdmin Views | `IsAdminUser` | Governs shop approvals, permissions, and subscriptions. | **Good** |

---

### 2.2 Shop & Menu Endpoints (`backend/shop/urls.py` & `backend/menu/urls.py`)
| Endpoint | Method | View Class | Permission | Observations & Defects | Severity |
| :--- | :---: | :--- | :--- | :--- | :---: |
| `/api/shop/` | `GET/PUT` | `ShopDetailView` | `IsAuthenticated` | Fetches/updates tenant shop details. | **Good** |
| `/api/shop/bill-template/` | `GET/PUT` | `BillTemplateView` | `IsAuthenticated` | Thermal receipt configuration (header, footer, tax display). | **Good** |
| `/api/menu/categories/` | `GET/POST`| `CategoryListCreateView` | `IsAuthenticated` | Lists and creates menu categories. | **Good** |
| `/api/menu/items/` | `GET/POST`| `MenuItemListCreateView` | `IsAuthenticated` | Lists and creates menu items. Supports multipart image upload. | **Good** |
| `/api/menu/items/<pk>/toggle/`| `POST` | `ToggleItemAvailabilityView` | `IsAuthenticated` | Toggles item availability switch (`is_available`). | **Good** |
| `/api/menu/by-category/` | `GET` | `MenuByCategoryView` | `IsAuthenticated` | Nested category-item tree for POS billing screen. | **Good** |

---

### 2.3 Token, Billing & Kitchen Endpoints (`backend/tokens/urls.py`)
| Endpoint | Method | View Class | Permission | Observations & Defects | Severity |
| :--- | :---: | :--- | :--- | :--- | :---: |
| `/api/tokens/` | `GET` | `TokenListView` | `IsAuthenticated` | Paginated token list with date and status filters. | **Good** |
| `/api/tokens/create/` | `POST` | `CreateTokenView` | `IsAuthenticated` | Creates token and bill items. If customer phone is provided, automatically creates/updates `Customer` model. | **Good** |
| `/api/tokens/<pk>/` | `GET/PUT` | `TokenDetailView` | `IsAuthenticated` | Retrieves/updates token detail. | **Good** |
| `/api/tokens/<pk>/payment/`| `POST` | `ProcessPaymentView` | `IsAuthenticated` | Marks bill paid or updates partial payment and balance due. | **Good** |
| `/api/tokens/<pk>/cancel/` | `POST` | `CancelTokenView` | `IsAuthenticated` | Sets status='cancelled'. Excluded from revenue calculations. | **Good** |
| `/api/tokens/summary/today/` | `GET` | `TodaySummaryView` | `IsAuthenticated` | Calculates daily totals for Dashboard. Contains calculation flaws. | **P1** |
| `/api/tokens/kitchen/` | `GET` | `KitchenView` | `IsAuthenticated` | Active KOT list (open and preparing tokens). | **Good** |
| `/api/tokens/customers/search/` | `GET` | `CustomerSearchAPIView` | `IsAuthenticated` | Autocompletes past customer names and phones from past tokens. | **P2** |

---

### 2.4 Customer & Ledger Endpoints (`backend/customers/urls.py`)
| Endpoint | Method | View Class | Permission | Observations & Defects | Severity |
| :--- | :---: | :--- | :--- | :--- | :---: |
| `/api/customers/` | `GET/POST`| `CustomerListCreateView`| `IsAuthenticated` | Lists active customers. **N+1 Query Issue:** Computes ledger summary for each customer in loop. | **P1** |
| `/api/customers/<pk>/` | `GET/PUT/DELETE`| `CustomerDetailView` | `IsAuthenticated` | Soft delete via `perform_destroy` setting `status='inactive'`. | **Good** |
| `/api/customers/<pk>/ledger/`| `GET` | `CustomerLedgerView` | `IsAuthenticated` | Returns full ledger summary (Total Billed, Total Paid, Net Due), bills, and payments. | **Good** |
| `/api/customers/<pk>/pay-due/`| `POST` | `CustomerPayDueView` | `IsAuthenticated` | Settles outstanding Udhar bills and creates `CustomerPayment`. | **Good** |
| `/api/customers/<pk>/credit/` | `POST` | `CustomerCreditView` | `IsAuthenticated` | Manual Credit (Advance Jama) — decreases Net Due. | **Good** |
| `/api/customers/<pk>/debit/` | `POST` | `CustomerDebitView` | `IsAuthenticated` | Manual Debit (Manual Charge) — increases Net Due. | **Good** |

---

## 3. Deep Dive into Critical Logic Defects

### 3.1 Reporting Mathematical Discrepancy (Daily vs Weekly/Monthly) (P1)
In [backend/reports/views.py](file:///d:/DharmikProject/billing%20application/backend/reports/views.py):
- **Daily Report** ([line 17](file:///d:/DharmikProject/billing%20application/backend/reports/views.py#L17)):
  ```python
  tokens = Token.objects.filter(date=target_date).exclude(status='cancelled')
  agg = tokens.aggregate(total_sales=Sum('total'), total_tokens=Count('id'))
  ```
  `DailyReportView` counts **all tokens** (both paid bills and unpaid Udhar credit bills) towards `total_sales`.
- **Weekly & Monthly Reports** ([lines 74 and 96](file:///d:/DharmikProject/billing%20application/backend/reports/views.py#L74,L96)):
  ```python
  tokens = Token.objects.filter(
      date__gte=start_date,
      date__lte=end_date,
      is_paid=True # <--- CRITICAL INCONSISTENCY!
  ).exclude(status='cancelled')
  ```
- **Consequence:** If a restaurant generates ₹10,000 in sales today (where ₹8,000 was paid cash and ₹2,000 was unpaid Udhar):
  - Today's Daily Report shows: **₹10,000**
  - But the Weekly and Monthly Reports for this same day only show: **₹8,000**
  - The weekly total does NOT equal the sum of the 7 daily reports. The merchant's accounting reports do not reconcile.

---

### 3.2 Flawed Sales Breakdown in `TodaySummaryView` (P1)
In [backend/tokens/views.py](file:///d:/DharmikProject/billing%20application/backend/tokens/views.py#L481-L487):
```python
# Cash received today
cash_paid = tokens.filter(payment_mode__iexact='cash', is_paid=True).aggregate(s=Sum('total'))['s'] or tokens.filter(payment_mode__iexact='cash').aggregate(s=Sum('received_amount'))['s'] or 0

# UPI received today
upi_paid = tokens.filter(payment_mode__in=['online / upi', 'upi', 'online', 'ONLINE', 'UPI'], is_paid=True).aggregate(s=Sum('total'))['s'] or tokens.filter(payment_mode__in=['online / upi', 'upi', 'online', 'ONLINE', 'UPI']).aggregate(s=Sum('received_amount'))['s'] or 0
```
- **The Bug:** The Python `or` operator short-circuits. If `is_paid=True` bills total ₹5,000, the first operand is truthy. Python never executes or adds the second query! Therefore, any partial payment received on an Udhar bill is completely discarded from today's cash or online total!
- **Missing Collections:** Furthermore, if a customer pays their outstanding Udhar via the Customer Ledger / Pay Due screen, that transaction is saved in `CustomerPayment`. `TodaySummaryView` only queries `Token.objects` and completely ignores `CustomerPayment.objects`, undercounting daily till collections.

---

### 3.3 Severe N+1 Query Problem in `CustomerListCreateView` (P1)
In [backend/customers/serializers.py](file:///d:/DharmikProject/billing%20application/backend/customers/serializers.py#L22-L28):
```python
class CustomerSerializer(serializers.ModelSerializer):
    net_due = serializers.SerializerMethodField()
    ...
    def get_net_due(self, obj):
        from .views import compute_customer_ledger_summary
        summary = compute_customer_ledger_summary(obj)
        return float(summary['net_due'])
```
- For every customer in the queryset, `compute_customer_ledger_summary` executes:
  1. `Token.objects.filter(customer_phone=customer.mobile_number)`
  2. `CustomerPayment.objects.filter(customer=customer)`
- For 100 customers, this triggers **201 database queries** on a single HTTP GET request!
- As customer count grows beyond 500, response times degrade from milliseconds to several seconds, leading to HTTP 504 gateway timeouts on mobile POS clients.

---

### 3.4 Multi-Tenancy Middleware in Local Development vs Production (P2)
In [backend/restaurant_pos/middleware.py](file:///d:/DharmikProject/billing%20application/backend/restaurant_pos/middleware.py#L10-L50):
- `JWTAuthenticationTenantMiddleware` inspects `user.shop.schema_name` and runs `connection.set_schema(shop.schema_name)`.
- In production with PostgreSQL (`django_tenants.postgresql_backend`), this correctly partitions tables across database schemas.
- In local development or fallback mode where `DATABASE_URL` is unset ([settings.py line 100](file:///d:/DharmikProject/billing%20application/backend/restaurant_pos/settings.py#L100)), the engine is `django.db.backends.sqlite3`.
- SQLite does not support schemas. `connection.set_schema()` raises an `AttributeError`, caught silently in line 48:
  ```python
  except Exception as e:
      logger.error(f"Tenant schema middleware error: {e}")
  ```
- All tenant queries run against the default SQLite schema. Because models like `Token`, `MenuItem`, and `Customer` **do not have a `shop` foreign key**, all tenants share the exact same rows in SQLite with zero data isolation.

---

## 4. Recommended Remediation Plan (Backend)

| Priority | Issue | Recommended Fix | Target File |
| :---: | :--- | :--- | :--- |
| **P0** | Dev Backdoor Endpoints | Remove `DevUsersView` and `DevLoginView` from `backend/core/urls.py` and `views.py`. | [core/urls.py](file:///d:/DharmikProject/billing%20application/backend/core/urls.py#L38-L39) |
| **P0** | OTP in API Response | Remove `response_data['otp'] = code` from `SendOTPView` and `RegisterView`. | [core/views.py](file:///d:/DharmikProject/billing%20application/backend/core/views.py#L144,L172) |
| **P1** | Report Inconsistency | Standardize `WeeklyReportView` and `MonthlyReportView` to include all non-cancelled tokens, matching `DailyReportView`. Provide separate fields for `total_billed`, `total_collected`, and `unpaid_udhar`. | [reports/views.py](file:///d:/DharmikProject/billing%20application/backend/reports/views.py#L74,L96) |
| **P1** | `TodaySummaryView` Math | Correct `cash_paid` and `upi_paid` to sum both fully paid bills AND partial payments. Add aggregation over `CustomerPayment` for today's date. | [tokens/views.py](file:///d:/DharmikProject/billing%20application/backend/tokens/views.py#L481-L487) |
| **P1** | Customer N+1 Queries | Annotate `total_billed` and `total_paid` at the queryset level in `CustomerListCreateView` or compute `net_due` using a single subquery aggregation. | [customers/serializers.py](file:///d:/DharmikProject/billing%20application/backend/customers/serializers.py#L22) |
| **P2** | Seed Script Insecurity | Guard `seed_initial_data.py` to prevent overwriting superadmin credentials on every production deploy. | [seed_initial_data.py](file:///d:/DharmikProject/billing%20application/backend/seed_initial_data.py#L53) |
