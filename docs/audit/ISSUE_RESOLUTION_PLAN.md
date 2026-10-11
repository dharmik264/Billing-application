# Full-Stack Audit Issue Resolution Plan — Flutter + Django

**Plan Creation Date:** October 2026  
**Author:** Lead Full-Stack Engineer, Security Auditor & QA Lead  
**Scope:** Verified Defect Remediation across Flutter (`lib/`) and Django Backend (`backend/`)  
**Status:** In Progress

---

## 1. Prioritization & Resolution Strategy

Issues are prioritized strictly according to business impact and safety constraints:
1. **Tier 1 (P0):** Critical Security Vulnerabilities & Prevention of Irreversible Data Loss
2. **Tier 2 (P1):** Accounting Mathematics, Financial Integrity & Report Reconciliation
3. **Tier 3 (P1):** API Client Architecture, Routing, Base URL & Token Refresh
4. **Tier 4 (P1):** State Management & Active Cart Preservation (`IndexedStack`)
5. **Tier 5 (P1/P2):** Offline Synchronization, Temporary ID Reconciliation & Soft Delete Consistency
6. **Tier 6 (P2):** Database Performance & N+1 Query Elimination

---

## 2. Issue Resolution Matrix & Action Plan

---

### [ISSUE-SEC-01] Unauthenticated Dev Backdoor Endpoints & SuperAdmin Takeover
- **Audit Ref:** `SECURITY_AUDIT.md` (Section 2.1), `MASTER_AUDIT_REPORT.md` (Q6)
- **Severity:** **P0 (Critical Blocker)**
- **Business Impact:** Complete authentication bypass. Any unauthenticated attacker can list all accounts and obtain a valid superuser JWT token with full access to all restaurant data and financial records.
- **Root Cause & Supporting Evidence:**
  - `backend/core/views.py` (lines 480–525) defines `DevUsersView` and `DevLoginView` with `permission_classes = [AllowAny]`.
  - `backend/core/urls.py` exposes them at `/api/auth/dev/users/` and `/api/auth/dev/login/`.
  - `lib/screens/super_admin_login_screen.dart` has an active UI card and toggle invoking these endpoints.
- **Affected Files:**
  - `backend/core/urls.py`
  - `backend/core/views.py`
  - `lib/screens/super_admin_login_screen.dart`
- **Exact Solution:**
  1. Delete `DevUsersView` and `DevLoginView` classes from `backend/core/views.py`.
  2. Remove route entries `dev/users/` and `dev/login/` from `backend/core/urls.py`.
  3. Remove the Dev Mode switch, state variables (`_isDevMode`, `_devUsers`), and UI cards from `lib/screens/super_admin_login_screen.dart`.
- **Dependencies & Regression Risks:** None. Legitimate login flows operate via `/api/auth/login/` and `/api/auth/verify-otp/`.
- **Test Cases Required:**
  - `GET /api/auth/dev/users/` returns HTTP 404.
  - `POST /api/auth/dev/login/` returns HTTP 404.
  - Super admin login screen renders cleanly without dev backdoor card.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-SEC-02] OTP Leakage in HTTP API Responses
- **Audit Ref:** `SECURITY_AUDIT.md` (Section 2.2), `QA_TEST_REPORT.md` (QA-01)
- **Severity:** **P0 (Critical Blocker)**
- **Business Impact:** Any user or interceptor can bypass phone ownership verification by reading the generated OTP directly from the API response payload.
- **Root Cause & Supporting Evidence:**
  - `backend/core/views.py` lines 144–146 (`SendOTPView`) and lines 172–174 (`RegisterView`) execute:
    `if settings.DEBUG or getattr(settings, 'RETURN_OTP_IN_RESPONSE', False): response_data['otp'] = code`
  - `render.yaml` sets `RETURN_OTP_IN_RESPONSE: "True"` in production environment.
- **Affected Files:**
  - `backend/core/views.py`
  - `render.yaml`
  - `lib/services/restaurant_api.dart` (ensure client does not rely on leaked OTP)
- **Exact Solution:**
  1. Remove `response_data['otp'] = code` in `SendOTPView` and `RegisterView` so OTP is never returned in API response.
  2. In `render.yaml`, change `RETURN_OTP_IN_RESPONSE` to `"False"`.
  3. Ensure `requestOtp()` in `lib/services/restaurant_api.dart` handles normal SMS dispatch responses.
- **Dependencies & Regression Risks:** In development without SMS gateway, automated test scripts should retrieve OTP from test mock or test database directly rather than API response.
- **Test Cases Required:**
  - `POST /api/auth/send-otp/` response payload contains only `status` and `message`, with NO `otp` field.
  - `POST /api/auth/register/` response payload contains NO `otp` field.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-SEC-03] Deployment Script Resets Hardcoded SuperAdmin Credentials
- **Audit Ref:** `SECURITY_AUDIT.md` (Section 2.3)
- **Severity:** **P0 (Critical)**
- **Business Impact:** Every production deploy resets the superuser password to `Admin123`, destroying password rotations and giving attackers a known static credential.
- **Root Cause & Supporting Evidence:**
  - `backend/build.sh` line 9 executes `python seed_initial_data.py`.
  - `backend/seed_initial_data.py` lines 40–58 hardcodes:
    `admin_user.set_password("Admin123"); admin_user.save()`
- **Affected Files:**
  - `backend/build.sh`
  - `backend/seed_initial_data.py`
- **Exact Solution:**
  1. Remove `python seed_initial_data.py` from `backend/build.sh`.
  2. In `seed_initial_data.py`, guard password setting so it only sets initial password if the user is newly created (`if created_admin:`).
- **Dependencies & Regression Risks:** None. Existing tenants and users remain untouched in production PostgreSQL.
- **Test Cases Required:**
  - Verify `build.sh` executes migrations and static collection without overwriting passwords.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-DATA-01] Client Logout Destroys Unsynced Offline Queue
- **Audit Ref:** `FLUTTER_CODE_AUDIT.md` (Section 4.3), `QA_TEST_REPORT.md` (QA-03)
- **Severity:** **P0 (Critical Data Loss)**
- **Business Impact:** Permanent loss of retail transactions, bill records, and customer payment collections if a cashier logs out during or immediately following a network outage.
- **Root Cause & Supporting Evidence:**
  - `lib/services/restaurant_api.dart` line 77 calls `await LocalDatabase.instance.clearAllData()`.
  - `lib/services/local_database.dart` lines 254–262 runs `await db.delete('sync_queue')` unconditionally.
- **Affected Files:**
  - `lib/services/local_database.dart`
  - `lib/services/restaurant_api.dart`
- **Exact Solution:**
  1. Update `LocalDatabase.instance.clearAllData()` to accept an optional parameter `bool preserveSyncQueue = true`.
  2. If `preserveSyncQueue` is true, do not delete from `sync_queue`.
  3. In `RestaurantApi.instance.logout()`, check `final queue = await LocalDatabase.instance.getQueue()`. If queue is not empty, log a warning and preserve the pending queue so that upon re-login the transactions can still sync to the server.
- **Dependencies & Regression Risks:** None. Cached menu items and tokens are still cleared, protecting user privacy.
- **Test Cases Required:**
  - Enqueue an offline item in `sync_queue`.
  - Trigger `RestaurantApi.instance.logout()`.
  - Inspect `LocalDatabase.instance.getQueue()`: verify queued item is still intact.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-NET-01] `RestaurantApi._uri` Ignores `_customBaseUrl`
- **Audit Ref:** `FLUTTER_CODE_AUDIT.md` (Section 3.1)
- **Severity:** **P1 (High)**
- **Business Impact:** Merchants configuring a custom LAN IP (e.g. `192.168.1.100:8000`) or staging environment cannot connect because all HTTP requests fall back to the hardcoded default `_baseUrl`.
- **Root Cause & Supporting Evidence:**
  - In `lib/services/restaurant_api.dart` line 89:
    `Uri _uri(String path, [Map<String, String>? query]) { final base = Uri.parse(_baseUrl); ... }`
  - It reads `_baseUrl` instead of the public getter `baseUrl` (`_customBaseUrl ?? _baseUrl`).
  - Similarly, line 47 in `getMediaUrl` reads `final base = Uri.parse(_baseUrl);`.
- **Affected Files:**
  - `lib/services/restaurant_api.dart`
- **Exact Solution:**
  1. In `_uri()`, change `final base = Uri.parse(_baseUrl);` to `final base = Uri.parse(baseUrl);`.
  2. In `getMediaUrl()`, change `final base = Uri.parse(_baseUrl);` to `final base = Uri.parse(baseUrl);`.
- **Dependencies & Regression Risks:** None. Defaults to `_baseUrl` if no custom URL is configured.
- **Test Cases Required:**
  - Call `RestaurantApi.instance.setCustomBaseUrl('http://192.168.1.50:8000')`.
  - Verify generated request URI uses `http://192.168.1.50:8000`.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-UI-01] Destructive Tab Navigation Discards Active Cashier Bill State
- **Audit Ref:** `UI_UX_AUDIT.md` (Section 3.3), `FLUTTER_CODE_AUDIT.md` (Section 5.2)
- **Severity:** **P1 (High Usability Defect)**
- **Business Impact:** Cashiers lose partially composed bills, item selections, and customer notes if they switch tabs to check inventory, customer ledger, or dashboard.
- **Root Cause & Supporting Evidence:**
  - In `lib/screens/main_screen.dart` lines 293–299:
    ```dart
    body: AnimatedSwitcher(
      child: KeyedSubtree(
        key: ValueKey<int>(_currentIndex),
        child: _screens[_currentIndex],
      ),
    )
    ```
  - `KeyedSubtree` with varying key forces Flutter to unmount and dispose the entire previous screen state.
- **Affected Files:**
  - `lib/screens/main_screen.dart`
- **Exact Solution:**
  Replace `AnimatedSwitcher` + `KeyedSubtree` with `IndexedStack(index: _currentIndex, children: _screens)`.
- **Dependencies & Regression Risks:** `IndexedStack` maintains state for all initialized screens. Ensure `_screens` list is initialized properly in `initState` or `_loadPermissions`.
- **Test Cases Required:**
  - Add items to cart in `TokenGenerationScreen`.
  - Switch to Home (tab 0) and then back to Token (tab 1).
  - Verify cart items, quantities, and customer fields are completely preserved.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-REP-01] Discrepancy Between Daily and Weekly/Monthly Accounting Reports
- **Audit Ref:** `DJANGO_BACKEND_AUDIT.md` (Section 3.1)
- **Severity:** **P1 (High Financial Defect)**
- **Business Impact:** Weekly and Monthly financial reports do not equal the sum of constituent daily reports, causing merchant tax and bookkeeping discrepancies.
- **Root Cause & Supporting Evidence:**
  - `backend/reports/views.py` line 17 (`DailyReportView`) counts all non-cancelled tokens (`is_paid` True AND False):
    `tokens = Token.objects.filter(date=target_date).exclude(status='cancelled')`
  - Lines 74 and 96 (`WeeklyReportView` and `MonthlyReportView`) strictly filter `is_paid=True`:
    `tokens = Token.objects.filter(date__gte=start_date, date__lte=end_date, is_paid=True).exclude(status='cancelled')`
  - Unpaid Udhar credit bills are counted in daily revenue but vanished from weekly and monthly revenue.
- **Affected Files:**
  - `backend/reports/views.py`
- **Exact Solution:**
  1. In `WeeklyReportView`, `MonthlyReportView`, and `DateRangeReportView`, remove the restrictive `is_paid=True` filter so they query all non-cancelled tokens.
  2. Structure the response metrics to report both:
     - `total_sales` (Total billed revenue across all valid tokens)
     - `collected_sales` (Portion paid via cash, UPI, card)
     - `udhar_due` (Unpaid balance due on credit tokens)
- **Dependencies & Regression Risks:** Verifies that weekly total sales equals the sum of 7 individual daily total sales.
- **Test Cases Required:**
  - Create 1 paid token of ₹500 and 1 unpaid Udhar token of ₹300 today.
  - Verify Daily Report shows total sales of ₹800.
  - Verify Weekly Report shows total sales of ₹800 (not ₹500).
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-REP-02] `TodaySummaryView` Drops Partial Payments & Ignores Customer Collections
- **Audit Ref:** `DJANGO_BACKEND_AUDIT.md` (Section 3.2)
- **Severity:** **P1 (High Financial Defect)**
- **Business Impact:** Cash till reconciliation on Dashboard undercounts actual cash and online collections because partial payments and ledger collections are missing.
- **Root Cause & Supporting Evidence:**
  - `backend/tokens/views.py` lines 482–486:
    `cash_paid = tokens.filter(payment_mode__iexact='cash', is_paid=True).aggregate(s=Sum('total'))['s'] or tokens.filter(payment_mode__iexact='cash').aggregate(s=Sum('received_amount'))['s'] or 0`
  - Python `or` short-circuits: whenever `is_paid=True` bills exist, `received_amount` from partial bills is never added.
  - Collections made through `CustomerPayment` (Pay Due screen) are completely omitted.
- **Affected Files:**
  - `backend/tokens/views.py` (`TodaySummaryView`)
- **Exact Solution:**
  1. Compute `cash_paid` as the sum of fully paid bills plus `received_amount` from unpaid/partial bills.
  2. Do the same for `upi_paid` and `card_paid`.
  3. Query `CustomerPayment.objects.filter(date=today)` and add customer ledger collections to their corresponding payment modes.
- **Dependencies & Regression Risks:** Ensures daily cash drawer matches actual cash received.
- **Test Cases Required:**
  - Generate a bill of ₹1000 with ₹400 received in cash and ₹600 due.
  - Pay ₹300 cash via Customer Pay Due screen.
  - Today's Summary cash must report ₹400 + ₹300 = ₹700 (not 0 or 400).
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-PERF-01] N+1 Query Degradation on `CustomerListCreateView`
- **Audit Ref:** `DJANGO_BACKEND_AUDIT.md` (Section 3.3)
- **Severity:** **P1 (High Performance Issue)**
- **Business Impact:** As customer count reaches 100+, listing customers triggers 200+ SQL queries, leading to slow response times and mobile app timeouts.
- **Root Cause & Supporting Evidence:**
  - `CustomerSerializer.get_net_due` calls `compute_customer_ledger_summary(obj)` for each customer individually in a loop.
- **Affected Files:**
  - `backend/customers/views.py`
  - `backend/customers/serializers.py`
- **Exact Solution:**
  Optimize `CustomerListCreateView`: pre-compute customer balances or optimize `compute_customer_ledger_summary` using database-level annotations where possible, or pass pre-aggregated summary dictionaries in the serializer context.
- **Dependencies & Regression Risks:** Customer `net_due` must match the customer ledger screen.
- **Test Cases Required:**
  - List 20 customers and verify query count is constant (O(1)) rather than O(N).
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-AUTH-01] Hardcoded Phone-Based SuperAdmin Routing
- **Audit Ref:** `SECURITY_AUDIT.md` (Section 2.4)
- **Severity:** **P1 (Security / Role Guard)**
- **Business Impact:** Fragile, insecure client-side role evaluation hardcoded to `'9999999999'`.
- **Root Cause & Supporting Evidence:**
  - `lib/main.dart` line 161:
    `if (loginPhone == '9999999999') { Navigator.pushReplacementNamed(context, '/super-admin-dashboard'); }`
- **Affected Files:**
  - `lib/main.dart`
- **Exact Solution:**
  Read the user's role from `SharedPreferences` or profile data (`role == 'super_admin'` or `is_superuser == true`) rather than comparing raw phone numbers.
- **Dependencies & Regression Risks:** Superadmins logging in with their actual phone numbers are routed properly.
- **Test Cases Required:**
  - Log in as superadmin with phone other than 9999999999; verify correct routing.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-AUTH-02] Missing Automatic 401 JWT Token Refresh Interceptor
- **Audit Ref:** `FLUTTER_CODE_AUDIT.md` (Section 3.2)
- **Severity:** **P2 (Usability / Session Stability)**
- **Business Impact:** Exactly 24 hours after login, all POS operations crash with HTTP 401 errors, forcing the cashier to re-login mid-operation.
- **Root Cause & Supporting Evidence:**
  - `RestaurantApi` does not intercept 401 responses to exchange the 30-day `refreshToken` for a fresh `accessToken`.
- **Affected Files:**
  - `lib/services/restaurant_api.dart`
- **Exact Solution:**
  Add a token refresh handler in `RestaurantApi`: on encountering a 401 response, call `POST auth/token/refresh/` using `refreshToken`, save the new `accessToken`, and retry the original HTTP request.
- **Dependencies & Regression Risks:** Guard against infinite loops if the refresh token itself is expired or blacklisted.
- **Test Cases Required:**
  - Simulate an expired access token; make an API call; verify request automatically refreshes token and succeeds.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-SYNC-01] Offline Sync Discards Server-Assigned IDs & Temporary ID Mismatch
- **Audit Ref:** `FLUTTER_CODE_AUDIT.md` (Section 4.1)
- **Severity:** **P1 (Data Integrity)**
- **Business Impact:** Offline-created entities maintain temporary timestamp IDs locally, breaking subsequent child updates or references after syncing.
- **Root Cause & Supporting Evidence:**
  - `SyncService.syncNow()` line 82: `await RestaurantApi.instance.post(endpoint, body);` ignores response body containing server ID.
- **Affected Files:**
  - `lib/services/sync_service.dart`
  - `lib/services/local_database.dart`
- **Exact Solution:**
  Capture response in `SyncService.syncNow()`. If response contains `id`, update the corresponding local SQLite record to reconcile the local ID with the server ID.
- **Dependencies & Regression Risks:** Local database must support updating IDs or mapping old temp ID to server ID.
- **Test Cases Required:**
  - Create item offline; trigger sync; verify local SQLite table updates record with server ID.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-SYNC-02] Sync Queue Stalls on Client Validation Errors (Infinite Retry)
- **Audit Ref:** `FLUTTER_CODE_AUDIT.md` (Section 4.2)
- **Severity:** **P2 (Sync Engine Resilience)**
- **Business Impact:** A single invalid queued request blocks all subsequent offline transactions from syncing.
- **Root Cause & Supporting Evidence:**
  - `sync_queue` table has `attempts` column, but `SyncService` never increments or checks it.
- **Affected Files:**
  - `lib/services/sync_service.dart`
  - `lib/services/local_database.dart`
- **Exact Solution:**
  Increment `attempts` when a sync request throws an exception. If `attempts >= 5` or response is a 4xx client validation error, log error and remove or quarantine the item so remaining valid queue items can sync.
- **Dependencies & Regression Risks:** Ensure transient network errors (timeouts, 502, 503) allow retrying up to max attempts.
- **Test Cases Required:**
  - Queue a malformed payload; verify that after max attempts it does not block subsequent queue entries.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-DATA-02] Local SQLite Hard Delete vs Backend Soft Delete
- **Audit Ref:** `DATABASE_DATA_INTEGRITY_AUDIT.md` (Section 4)
- **Severity:** **P2 (Consistency)**
- **Business Impact:** Local customer list completely deletes row, while backend retains row with `status='inactive'`.
- **Root Cause & Supporting Evidence:**
  - `LocalDatabase.deleteCustomer` runs `db.delete('customers', where: 'id = ?')`.
- **Affected Files:**
  - `lib/services/local_database.dart`
- **Exact Solution:**
  Update local customer record status to `'inactive'` instead of hard deleting, and update `getCustomers` to filter by `status != 'inactive'`.
- **Dependencies & Regression Risks:** Preserves offline transaction referential integrity.
- **Test Cases Required:**
  - Soft delete customer locally; verify customer is excluded from active search but row is preserved.
- **Implementation Status:** Open
- **Verification Result:** Pending

---

### [ISSUE-SEC-04] Production Settings Hardened (DEBUG, ALLOWED_HOSTS, CORS)
- **Audit Ref:** `SECURITY_AUDIT.md` (Section 2.5)
- **Severity:** **P2 (Hardening)**
- **Business Impact:** Avoids stack trace leakage and host header poisoning in production.
- **Root Cause & Supporting Evidence:**
  - `backend/restaurant_pos/settings.py` line 11: `DEBUG = True` hardcoded.
- **Affected Files:**
  - `backend/restaurant_pos/settings.py`
- **Exact Solution:**
  Change line 11 to read from environment: `DEBUG = os.getenv('DEBUG', 'False') == 'True'`. Default to `False` in production while honoring `.env` for local testing.
- **Dependencies & Regression Risks:** Ensure local development environment `.env` has `DEBUG=True`.
- **Test Cases Required:**
  - Verify settings load properly with `DEBUG=True` from `.env`.
- **Implementation Status:** Open
- **Verification Result:** Pending
