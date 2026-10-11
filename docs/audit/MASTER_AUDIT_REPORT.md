# Full-Stack Application Master Audit Report — Flutter + Django

**Audit Execution Date:** October 2026  
**Auditor Lead:** Antigravity Full-Stack Application Audit Team  
**System Analyzed:** Restaurant Billing & Accounting Multi-Tenant Platform  
**Client:** Flutter (Dart 3.x, Flutter SDK 3.x)  
**Backend:** Python 3.12, Django 5.x, DRF 3.15, `django-tenants 3.7.0`  
**Databases:** PostgreSQL 16 (Production via Render) & SQLite 3 (Dev / Offline POS Client)

---

## 1. Executive Summary & Health Scorecard

A comprehensive, read-only architectural, code, security, and usability audit of the complete application was performed across both the Flutter client (`lib/`) and the Django backend (`backend/`).

### Overall System Health Scorecard:
```
┌──────────────────────────────────────┬─────────┬────────────────────────────────────────────┐
│ Domain                               │ Score   │ Primary Assessment                         │
├──────────────────────────────────────┼─────────┼────────────────────────────────────────────┤
│ 1. Application Security              │ 32/100  │ CRITICAL: Backdoor dev endpoints, OTP leak │
│ 2. Accounting & Financial Integrity  │ 68/100  │ HIGH RISK: Daily vs Weekly report mismatch │
│ 3. Offline Sync & Local Storage      │ 62/100  │ HIGH RISK: Data loss on logout, ID desync  │
│ 4. Flutter Code & State Management   │ 74/100  │ MEDIUM: Destructive tab navigation state   │
│ 5. UI/UX & Usability                 │ 84/100  │ GOOD: Clean POS card layouts, fast billing │
│ 6. QA & Test Automation Infrastructure│ 40/100 │ POOR: 0 Flutter tests in test/ directory   │
└──────────────────────────────────────┴─────────┴────────────────────────────────────────────┘
 OVERALL PLATFORM HEALTH: 60/100 (REMEDIATION REQUIRED BEFORE SCALE)
```

---

## 2. Answers to the 10 Core Architectural Questions

### Q1: What is the database in use, and how is it configured?
**Answer:** The application uses a dual-engine architecture:
- In production, it utilizes **PostgreSQL 16** (`billing-db` provisioned via `render.yaml`) driven by `django_tenants.postgresql_backend`.
- In local development, it falls back to **SQLite 3** (`backend/db.sqlite3`).
- On the mobile/desktop client, it uses **SQLite 3** via `sqflite` (Android/iOS) and `sqflite_common_ffi` (Windows/macOS/Linux) at `local_billing.db` to power offline billing.

### Q2: How does multi-tenancy operate, and what are its boundaries?
**Answer:** Multi-tenancy is implemented using **PostgreSQL schema isolation** via `django-tenants`:
- The `public` schema houses shared models: `core.User`, `shop.Shop`, and `shop.Domain`.
- Each restaurant/merchant tenant is provisioned an isolated PostgreSQL schema (e.g., `dharmik_shop`). Tenant models (`menu`, `tokens`, `customers`, `reports`, `printer`) reside exclusively inside their respective schema.
- Tenant resolution on API calls is handled via [JWTAuthenticationTenantMiddleware](file:///d:/DharmikProject/billing%20application/backend/restaurant_pos/middleware.py): the middleware decodes the Bearer token, extracts `user.shop.schema_name`, and executes `connection.set_schema(shop.schema_name)`.
- **Architectural Risk:** Because tenant models do NOT contain a `shop` foreign key, running the project against SQLite in local development disables schema isolation, causing all tenants to share the same tables without isolation.

### Q3: What is the Flutter state management approach and where does it fail?
**Answer:** The client uses vanilla `StatefulWidget` / `setState` combined with static `ChangeNotifier` / `ValueNotifier` event buses ([BillEventNotifier](file:///d:/DharmikProject/billing%20application/lib/utils/bill_event_notifier.dart)).
- **Primary Failure Point:** In [main_screen.dart](file:///d:/DharmikProject/billing%20application/lib/screens/main_screen.dart#L293-L299), tabs switch using `AnimatedSwitcher` + `KeyedSubtree` instead of `IndexedStack`. Every tab transition destroys and reconstructs the active screen widget tree, wiping active cashier shopping carts, customer searches, and scroll positions.

### Q4: How does offline data storage and sync operate, and what are the failure modes?
**Answer:** Offline mode uses local SQLite tables (`tokens`, `customers`, `items`, `sync_queue`):
- When offline, creations are saved locally with a millisecond timestamp ID (`'1728612345678'`) and inserted into `sync_queue`.
- When connectivity resumes, [SyncService](file:///d:/DharmikProject/billing%20application/lib/services/sync_service.dart) flushes items via HTTP POST.
- **Critical Failure Mode 1 (Data Loss):** Logging out calls `LocalDatabase.instance.clearAllData()`, which wipes `sync_queue` without checking for unsynced transactions.
- **Critical Failure Mode 2 (ID Desync):** Sync discards the server's newly assigned PostgreSQL integer ID, leaving local records pointing to invalid temporary IDs.
- **Critical Failure Mode 3 (Infinite Loop):** Failed sync requests are retried indefinitely with no maximum attempt ceiling.

### Q5: Are financial and accounting calculations accurate and consistent across screens?
**Answer:** **No.** We identified two major discrepancies:
1. **Daily vs Weekly/Monthly Reports:** [DailyReportView](file:///d:/DharmikProject/billing%20application/backend/reports/views.py#L17) includes all tokens (paid and unpaid Udhar), while [WeeklyReportView](file:///d:/DharmikProject/billing%20application/backend/reports/views.py#L74) and [MonthlyReportView](file:///d:/DharmikProject/billing%20application/backend/reports/views.py#L96) strictly filter `is_paid=True`. Weekly totals do not equal the sum of their constituent daily reports.
2. **`TodaySummaryView` Sales Breakdown:** Uses Python `or` short-circuiting between fully paid and partial payments, dropping partial Udhar collections, and completely ignores payments made through `CustomerPayment` (Pay Due screen).

### Q6: What critical security vulnerabilities exist in the codebase?
**Answer:** Three critical (P0) vulnerabilities were verified:
1. **Unauthenticated Dev Backdoors:** `GET /api/auth/dev/users/` lists all users, and `POST /api/auth/dev/login/` generates superadmin JWT tokens with zero password verification. A 1-tap exploit toggle exists in the frontend login screen.
2. **OTP Leaked in API Responses:** Both `SendOTPView` and `RegisterView` return `response_data['otp'] = code`, and Render production config sets `RETURN_OTP_IN_RESPONSE = True`.
3. **Hardcoded Credentials Reset on Deploy:** `build.sh` runs `seed_initial_data.py` on every deploy, resetting superadmin passwords to `Admin123`.

### Q7: How does customer soft-delete interact with ledger accounting and dashboard metrics?
**Answer:**
- Soft delete sets `status = 'inactive'` in the backend.
- `CustomerListCreateView` and `CustomerDetailView` exclude inactive customers.
- In [dashboard_screen.dart](file:///d:/DharmikProject/billing%20application/lib/screens/dashboard_screen.dart#L161-L164), total customer net due is computed by summing `c.netDue` over active customers returned by the API. Inactive customers are excluded from the total net due, satisfying the business requirement.
- **Integrity Defect:** The local SQLite client performs a hard `DELETE` from `customers`, diverging from the server's soft-delete status.

### Q8: How is peripheral hardware (thermal printers) integrated and handled?
**Answer:** Integrated via [PrinterService](file:///d:/DharmikProject/billing%20application/lib/services/printer_service.dart) utilizing `esc_pos_utils_plus` and `printing`:
- Supports 58mm and 80mm thermal receipt formats.
- Connects via Bluetooth, USB, and Network (TCP/IP socket).
- Features auto-reconnect on application launch and background print queueing.
- Includes real-time font size scaling and print preview canvas.

### Q9: What testing harnesses exist, and what is our quality assurance posture?
**Answer:**
- **Frontend:** **0% test coverage.** The `test/` directory is completely empty. No widget, unit, or driver tests exist.
- **Backend:** 4 standalone integration test scripts exist in `backend/` (`test_customer_ledger.py`, `test_customer_module.py`, `test_full_app.py`, `test_multi_tenancy.py`), which all pass.

### Q10: What is the deployment architecture, CI/CD pipeline, and hosting configuration?
**Answer:** Configured via [render.yaml](file:///d:/DharmikProject/billing%20application/render.yaml):
- Hosted as a Python Web Service on Render with a managed PostgreSQL database (`billing-db`).
- Gunicorn WSGI server with concurrency of 4 workers.
- Static assets served via WhiteNoise; media optionally routed to AWS S3.
- `build.sh` runs dependencies install, `collectstatic`, `migrate_schemas`, and seed scripts.

---

## 3. Prioritized Defect & Risk Matrix

| Severity | Issue Description | Affected Files | Effort Estimate |
| :---: | :--- | :--- | :---: |
| **P0** | Dev Backdoor Endpoints allow unauthenticated SuperAdmin takeover | `backend/core/urls.py`, `backend/core/views.py`, `lib/screens/super_admin_login_screen.dart` | 1 hour |
| **P0** | OTP leaked in HTTP API JSON response in production | `backend/core/views.py`, `render.yaml` | 30 mins |
| **P0** | `build.sh` re-seeds hardcoded credentials (`Admin123`) on every deploy | `backend/build.sh`, `backend/seed_initial_data.py` | 30 mins |
| **P0** | Client logout wipes `sync_queue`, permanently destroying unsynced bills | `lib/services/restaurant_api.dart`, `lib/services/local_database.dart` | 1 hour |
| **P1** | Daily Report (all bills) and Weekly/Monthly Reports (`is_paid=True` only) do not reconcile | `backend/reports/views.py` | 2 hours |
| **P1** | `TodaySummaryView` drops partial Udhar collections due to Python `or` short-circuiting | `backend/tokens/views.py` | 2 hours |
| **P1** | `CustomerListCreateView` executes 200+ N+1 queries for 100 customers | `backend/customers/serializers.py`, `backend/customers/views.py` | 3 hours |
| **P1** | Destructive Tab Navigation destroys active cart and user state on tab switch | `lib/screens/main_screen.dart` | 1 hour |
| **P1** | `RestaurantApi._uri` ignores `_customBaseUrl` setting | `lib/services/restaurant_api.dart` | 30 mins |
| **P1** | Offline sync engine discards server IDs and fails to reconcile local SQLite IDs | `lib/services/sync_service.dart` | 4 hours |
| **P1** | Token join to Customer relies on denormalized phone string instead of Foreign Key | `backend/tokens/models.py`, `backend/customers/views.py` | 4 hours |
| **P1** | Hardcoded phone routing (`'9999999999'`) in Flutter splash screen | `lib/main.dart` | 30 mins |
| **P2** | No automatic 401 JWT token refresh interceptor in Flutter HTTP client | `lib/services/restaurant_api.dart` | 3 hours |
| **P2** | Plaintext token storage in `SharedPreferences` instead of secure keychain | `lib/services/restaurant_api.dart` | 2 hours |
| **P2** | Local SQLite executes hard DELETE while Django backend executes soft delete | `lib/services/local_database.dart` | 1 hour |
| **P2** | Sync queue lacks maximum attempt ceiling, leading to infinite retry loops on 400 errors | `lib/services/sync_service.dart` | 2 hours |
| **P2** | DRF serializers cast monetary Decimals to Python floats | `backend/customers/views.py` | 2 hours |
| **P2** | Production settings have hardcoded `DEBUG = True` and wildcard CORS/Hosts | `backend/restaurant_pos/settings.py`, `render.yaml` | 1 hour |
| **P3** | Empty `test/` directory in Flutter client (zero widget or unit tests) | `test/` | 1 day |
| **P3** | Hardcoded Gujarati terminology without formal `intl` localization support | `lib/screens/` | 2 days |

---

## 4. Phased Remediation Roadmap

```
PHASE 1: Immediate Critical Security & Data Loss Fixes (Day 1)
  ├── 1.1 Delete /api/auth/dev/* backdoor endpoints and remove Dev Mode card from SuperAdmin login.
  ├── 1.2 Remove RETURN_OTP_IN_RESPONSE and strip 'otp' key from response payloads.
  ├── 1.3 Remove seed_initial_data.py from build.sh so deploy never overwrites admin passwords.
  ├── 1.4 Guard logout in Flutter: check sync_queue.length > 0 and block/warn before wipe.
  └── 1.5 Fix RestaurantApi._uri to respect custom base URL.

PHASE 2: Financial Mathematics & Backend Data Integrity (Days 2–3)
  ├── 2.1 Align Weekly & Monthly reports with Daily report logic (include all non-cancelled bills).
  ├── 2.2 Correct TodaySummaryView: sum full + partial collections and include CustomerPayment.
  ├── 2.3 Optimize CustomerListCreateView: eliminate N+1 queries via database annotations.
  ├── 2.4 Add customer foreign key to Token model to preserve history across phone updates.
  └── 2.5 Fix CustomerPayment cascade delete: change on_delete=CASCADE to models.PROTECT.

PHASE 3: Flutter State Management & Offline Sync Stability (Days 4–5)
  ├── 3.1 Migrate MainScreen from AnimatedSwitcher to IndexedStack to preserve cart state.
  ├── 3.2 Implement 401 JWT token auto-refresh interceptor in RestaurantApi.
  ├── 3.3 Reconcile server-assigned IDs into local SQLite during sync cycles.
  ├── 3.4 Add retry counter (attempts >= 5) and dead-letter quarantine to SyncService.
  └── 3.5 Align local SQLite customer delete to soft delete (status = 'inactive').

PHASE 4: Hardening, Usability & Test Automation (Week 2)
  ├── 4.1 Set DEBUG=False, configure restricted ALLOWED_HOSTS and CORS origins in settings.py.
  ├── 4.2 Migrate SharedPreferences auth tokens to flutter_secure_storage.
  ├── 4.3 Replace hardcoded phone '9999999999' check in main.dart with JWT role validation.
  ├── 4.4 Implement core Flutter unit tests for customer ledger calculations and widget tests for POS.
  └── 4.5 Add intl localization bundle for Gujarati / Hindi / English language toggles.
```

---

## 5. Audit Deliverables Directory

All 8 detailed audit documents are generated and available in `docs/audit/`:
1. [docs/audit/UI_UX_AUDIT.md](file:///d:/DharmikProject/billing%20application/docs/audit/UI_UX_AUDIT.md)
2. [docs/audit/FLUTTER_CODE_AUDIT.md](file:///d:/DharmikProject/billing%20application/docs/audit/FLUTTER_CODE_AUDIT.md)
3. [docs/audit/DJANGO_BACKEND_AUDIT.md](file:///d:/DharmikProject/billing%20application/docs/audit/DJANGO_BACKEND_AUDIT.md)
4. [docs/audit/DATABASE_DATA_INTEGRITY_AUDIT.md](file:///d:/DharmikProject/billing%20application/docs/audit/DATABASE_DATA_INTEGRITY_AUDIT.md)
5. [docs/audit/SECURITY_AUDIT.md](file:///d:/DharmikProject/billing%20application/docs/audit/SECURITY_AUDIT.md)
6. [docs/audit/QA_TEST_REPORT.md](file:///d:/DharmikProject/billing%20application/docs/audit/QA_TEST_REPORT.md)
7. [docs/audit/FEATURE_STORAGE_MAPPING.md](file:///d:/DharmikProject/billing%20application/docs/audit/FEATURE_STORAGE_MAPPING.md)
8. [docs/audit/MASTER_AUDIT_REPORT.md](file:///d:/DharmikProject/billing%20application/docs/audit/MASTER_AUDIT_REPORT.md)
