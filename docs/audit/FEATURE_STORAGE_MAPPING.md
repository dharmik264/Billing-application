# Complete Feature-to-Storage Traceability Mapping

**Audit Date:** October 2026  
**Auditor:** Lead Systems Architect & Full-Stack Engineer  
**Scope:** Complete End-to-End Traceability Matrix from UI Screen -> API Client -> Local Storage -> Backend Route -> View -> Model -> Database Table

---

## 1. Traceability Matrix

| Feature / Business Capability | Flutter Screen (`lib/screens/`) | API Service Method (`restaurant_api.dart`) | Local Client Storage (`sqflite` / `Prefs`) | Backend Endpoint (`backend/`) | Django View (`backend/`) | Django Model & PostgreSQL Table | Schema Scope & Persistence Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Password Login** | `password_login_screen.dart` | `login(phone, password)` | `Prefs['accessToken']`, `Prefs['refreshToken']` | `POST /api/auth/login/` | `PasswordLoginView` | `core.User` (`core_user`) | Public Schema / Persistent |
| **OTP Request** | `otp_login_screen.dart` | `requestOtp(mobile)` | None | `POST /api/auth/send-otp/` | `SendOTPView` | `core.User` (`core_user`) | Public Schema / Transient (SMS) |
| **OTP Verification**| `otp_login_screen.dart` | `verifyOtp(mobile, code)` | `Prefs['accessToken']`, `Prefs['refreshToken']` | `POST /api/auth/verify-otp/`| `VerifyOTPView` | `core.User` (`core_user`) | Public Schema / Persistent |
| **Merchant Registration**| `registration_screen.dart` | `register(payload)` | None | `POST /api/auth/register/` | `RegisterView` | `core.User`, `shop.Shop` | Public Schema / Persistent |
| **Shop Profile Config** | `shop_setup_screen.dart` | `updateShop(data)` | `sqflite.shop_data` | `PUT /api/shop/` | `ShopDetailView` | `shop.Shop` (`shop_shop`) | Public Schema / Persistent |
| **Bill Template Setup** | `settings_screen.dart` | `updateBillTemplate(data)` | `Prefs['billTemplate']` | `PUT /api/shop/bill-template/`| `BillTemplateView` | `shop.BillTemplate` (`shop_billtemplate`)| Tenant Schema / Persistent |
| **Category Management** | `item_management_screen.dart`| `fetchCategories()`, `createCategory()` | `sqflite.categories` (in memory) | `GET/POST /api/menu/categories/`| `CategoryListCreateView` | `menu.Category` (`menu_category`) | Tenant Schema / Persistent |
| **Menu Items Catalog** | `item_management_screen.dart`| `fetchItems()`, `createItem()` | `sqflite.items` | `GET/POST /api/menu/items/`| `MenuItemListCreateView`| `menu.MenuItem` (`menu_menuitem`)| Tenant Schema / Persistent |
| **Item Availability Toggle**| `item_management_screen.dart`| `toggleItemAvailability(id)` | `sqflite.items` | `POST /api/menu/items/<id>/toggle/`| `ToggleItemAvailabilityView`| `menu.MenuItem.is_available` | Tenant Schema / Persistent |
| **Token / Bill Generation**| `token_generation_screen.dart`| `createToken(tokenDraft)` | `sqflite.tokens`, `sqflite.sync_queue` | `POST /api/tokens/create/`| `CreateTokenView` | `tokens.Token`, `tokens.TokenItem` | Tenant Schema / Persistent |
| **Order Status Update** | `all_tokens_screen.dart` | `updateTokenStatus(id, st)` | `sqflite.tokens` | `POST /api/tokens/<id>/status/`| `UpdateTokenStatusView`| `tokens.Token.status` | Tenant Schema / Persistent |
| **Token Cancellation** | `all_tokens_screen.dart` | `cancelToken(id)` | `sqflite.tokens` | `POST /api/tokens/<id>/cancel/`| `CancelTokenView` | `tokens.Token.status='cancelled'` | Tenant Schema / Persistent |
| **Kitchen Display (KOT)** | `kitchen_slip_screen.dart` | `fetchKitchenTokens()` | None | `GET /api/tokens/kitchen/` | `KitchenView` | `tokens.Token` (status in open/prep)| Tenant Schema / Dynamic Query |
| **Customer Search Autocomplete**| `token_generation_screen.dart`| `searchCustomers(query)` | `sqflite.customers` | `GET /api/tokens/customers/search/`| `CustomerSearchAPIView`| `tokens.Token.customer_name/phone`| Tenant Schema / Dynamic Query |
| **Customer Directory** | `customer_management_screen.dart`| `fetchCustomers()` | `sqflite.customers` | `GET /api/customers/` | `CustomerListCreateView`| `customers.Customer` (`customers_customer`)| Tenant Schema / Persistent |
| **Customer Soft Delete**| `customer_management_screen.dart`| `deleteCustomer(id)` | `sqflite.customers` (Hard Delete)| `DELETE /api/customers/<id>/`| `CustomerDetailView` | `customers.Customer.status='inactive'`| Tenant Schema / Soft Delete |
| **Customer Ledger Summary**| `customer_ledger_screen.dart`| `fetchCustomerLedger(id)`| None | `GET /api/customers/<id>/ledger/`| `CustomerLedgerView` | Dynamic Aggregation over `Token` & `CustomerPayment`| Tenant Schema / Calculated |
| **Customer Pay Due (Udhar Settle)**| `customer_ledger_screen.dart`| `payCustomerDue(id, amount)`| `sqflite.sync_queue` | `POST /api/customers/<id>/pay-due/`| `CustomerPayDueView` | `customers.CustomerPayment`, `tokens.Token` | Tenant Schema / Persistent |
| **Manual Credit (Advance Jama)**| `customer_ledger_screen.dart`| `creditCustomer(id, amount)`| `sqflite.sync_queue` | `POST /api/customers/<id>/credit/`| `CustomerCreditView` | `customers.CustomerPayment(mode='M-Credit')`| Tenant Schema / Persistent |
| **Manual Debit (Manual Charge)**| `customer_ledger_screen.dart`| `debitCustomer(id, amount)` | `sqflite.sync_queue` | `POST /api/customers/<id>/debit/` | `CustomerDebitView` | `customers.CustomerPayment(mode='M-Debit')`| Tenant Schema / Persistent |
| **Home Dashboard Metrics**| `dashboard_screen.dart` | `fetchTodaySummary()`, `fetchShop()`| `sqflite.shop_data` | `GET /api/tokens/summary/today/`| `TodaySummaryView` | Aggregate over `tokens.Token` & `customers.Customer`| Tenant Schema / Calculated |
| **Daily Sales Report** | `analytics_reports_screen.dart`| `fetchDailyReport(date)` | None | `GET /api/reports/daily/` | `DailyReportView` | Aggregate over `tokens.Token` | Tenant Schema / Calculated |
| **Weekly Sales Report** | `analytics_reports_screen.dart`| `fetchWeeklyReport()` | None | `GET /api/reports/weekly/` | `WeeklyReportView` | Aggregate over `tokens.Token` (`is_paid=True`)| Tenant Schema / Calculated |
| **Monthly Sales Report**| `analytics_reports_screen.dart`| `fetchMonthlyReport(m, y)` | None | `GET /api/reports/monthly/`| `MonthlyReportView` | Aggregate over `tokens.Token` (`is_paid=True`)| Tenant Schema / Calculated |
| **Custom Date Range Report**| `analytics_reports_screen.dart`| `fetchRangeReport(from, to)`| None | `GET /api/reports/range/` | `DateRangeReportView` | Aggregate over `tokens.Token` | Tenant Schema / Calculated |
| **Printer Hardware Setup**| `printer_setup_screen.dart`| `savePrinter(config)` | `Prefs['printerConfig']` | `POST /api/printer/printers/`| `PrinterListCreateView` | `printer.Printer` (`printer_printer`)| Tenant Schema / Persistent |
| **Super Admin Shop Approval**| `super_admin_shop_requests_screen.dart`| `approveShop(id)` | None | `POST /api/auth/shop-requests/<id>/action/`| `ShopRequestActionView`| `core.User.account_status='approved'`, `shop.Shop`| Public Schema / Persistent |
| **Super Admin Role Permissions**| `super_admin_user_roles_screen.dart`| `updateUserPermissions(id, perms)`| `Prefs['permissions']` | `POST /api/auth/super-admin/users/<id>/permissions/`| `SuperAdminUpdatePermissionsView`| `core.User.permissions` (JSONField)| Public Schema / Persistent |
| **Subscription Plan Config**| `super_admin_plan_settings_screen.dart`| `savePlan(plan)` | None | `POST /api/auth/super-admin/plans/`| `SuperAdminSubscriptionPlanListCreateView`| `core.SubscriptionPlan` | Public Schema / Persistent |
| **Subscription Payment Verification**| `super_admin_payments_screen.dart`| `approvePayment(id)` | None | `POST /api/auth/super-admin/payments/`| `SuperAdminPaymentsView`| `core.SubscriptionPayment` | Public Schema / Persistent |

---

## 2. Storage Subsystem Characteristics

### 2.1 Multi-Tier Storage Topology
1. **Tier 1: Client Memory (RAM):**
   Active shopping cart line items, transient search filter queries, and active thermal preview canvases.
2. **Tier 2: Client Persistent Key-Value (`SharedPreferences`):**
   Authentication tokens (`accessToken`, `refreshToken`), user role and permissions map (`permissions`), thermal slip configuration (`billTemplate`), and default printer hardware address (`printerConfig`).
3. **Tier 3: Client Relational Storage (`sqflite` / `local_billing.db`):**
   Full cached copy of `shop_data`, `items`, `tokens`, `customers`, and the offline synchronization queue `sync_queue`.
4. **Tier 4: Server Relational Storage (PostgreSQL 16):**
   Shared public schema for global authentication and tenant routing; isolated PostgreSQL schemas (`<shop_schema>.*`) for all transactional restaurant and customer accounting records.
