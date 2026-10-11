# Comprehensive QA Test Report & Test Matrix

**Audit Date:** October 2026  
**Auditor:** QA Engineering Lead & Test Automation Architect  
**Scope:** Test Harness Coverage, Static Analysis, Automated Test Suites, Manual Verification Matrix, and Edge Case Failure Modes  
**Platforms Tested:** Flutter Multi-Platform (Android/Windows) & Python Django Backend

---

## 1. Test Automation Coverage & Infrastructure Status

### 1.1 Frontend (Flutter Client)
| Test Type | Directory / Suite | Test Count | Status / Coverage |
| :--- | :--- | :---: | :--- |
| **Unit Tests** | `test/` | 0 | **0% Coverage** (Directory is completely empty) |
| **Widget Tests** | `test/` | 0 | **0% Coverage** (No UI component tests exist) |
| **Integration Tests** | `integration_test/` | 0 | **0% Coverage** (No driver/E2E tests configured) |
| **Static Code Analysis**| `flutter analyze` | 34 screens | **PASSED** (0 errors, 0 warnings, 0 lints) |
| **Standalone Scripts** | `test_pdf.dart` | 1 | Functional validation of thermal receipt rendering |

### 1.2 Backend (Django REST Framework)
| Test Suite File | Focus Area | Status | Key Verifications |
| :--- | :--- | :---: | :--- |
| [backend/test_customer_ledger.py](file:///d:/DharmikProject/billing%20application/backend/test_customer_ledger.py) | Ledger Calculations | **PASSED** | Verifies `compute_customer_ledger_summary`, Net Due formula, M-Credit, and M-Debit. |
| [backend/test_customer_module.py](file:///d:/DharmikProject/billing%20application/backend/test_customer_module.py) | Customer Lifecycle | **PASSED** | CRUD endpoints, soft-delete filtering (`status='inactive'`), GSTIN validation. |
| [backend/test_full_app.py](file:///d:/DharmikProject/billing%20application/backend/test_full_app.py) | Full App E2E | **PASSED** | Auth, Shop config, Menu management, Token generation, and Report views. |
| [backend/test_multi_tenancy.py](file:///d:/DharmikProject/billing%20application/backend/test_multi_tenancy.py) | Tenant Isolation | **PASSED** | Validates schema switching logic via `django-tenants`. |

---

## 2. End-to-End Functional Test Verification Matrix

### Journey 1: Authentication & Merchant Onboarding
| Step | Test Action | Expected Result | Actual Result | Status |
| :---: | :--- | :--- | :--- | :---: |
| 1.1 | Register with valid phone, password & shop name | Shop request created with `account_status='pending'` | Creates user & pending shop record | **PASS** |
| 1.2 | Request OTP on registered phone | 6-digit OTP dispatched via SMS | OTP generated; **LEAKED in HTTP response** | **FAIL (P0)** |
| 1.3 | SuperAdmin approves shop request | Shop status changes to `'approved'`, tenant schema created | Status updated, schema migrated | **PASS** |
| 1.4 | Merchant logs in with password | Returns JWT Access & Refresh token pair | Authenticated successfully | **PASS** |
| 1.5 | SuperAdmin Dev Mode bypass | Dev mode restricted to authorized debuggers | Dev mode allows 1-tap passwordless login to any account | **FAIL (P0)** |

---

### Journey 2: Point-of-Sale Billing & Printing
| Step | Test Action | Expected Result | Actual Result | Status |
| :---: | :--- | :--- | :--- | :---: |
| 2.1 | Browse categories and add 3 items to cart | Cart subtotal, GST, and grand total calculate dynamically | Accurate real-time calculation | **PASS** |
| 2.2 | Select order type: Takeaway | Order type tag set to Takeaway on bill | Correctly saved in `order_type` | **PASS** |
| 2.3 | Generate Token & Print Receipt | Token number increments (e.g. #14), KOT created | Saved in DB; ESC/POS print payload formatted | **PASS** |
| 2.4 | Switch tabs to Customer Screen and return | Cart state should be preserved | **Cart is wiped** due to `AnimatedSwitcher` rebuilding screen | **FAIL (P1)** |
| 2.5 | Reprint receipt from All Tokens screen | Print preview modal opens with exact bill copy | Accurately re-renders bill | **PASS** |

---

### Journey 3: Customer Udhar (Credit) & Ledger Accounting
| Step | Test Action | Expected Result | Actual Result | Status |
| :---: | :--- | :--- | :--- | :---: |
| 3.1 | Generate bill with payment mode = Udhar | Bill saved with `is_paid=False`, `balance_due=total` | Saved correctly; customer ledger reflects debt | **PASS** |
| 3.2 | Check Customer Management screen | Customer Net Due reflects positive outstanding amount (Red) | Net Due displays correctly in Red | **PASS** |
| 3.3 | Customer pays full due via Pay Due modal | `CustomerPayment` created; token marked `is_paid=True`; Net Due becomes 0.00 | Net Due drops to 0.00; status becomes 'PAID IN FULL' | **PASS** |
| 3.4 | Customer advances money via M-Credit (Jama) | Net Due becomes negative (e.g. -₹500.00); color turns Green | Negative due displays correctly in Green | **PASS** |
| 3.5 | Attempt Pay Due when Net Due <= 0 | Error feedback: cannot pay due when no balance is owed | Blocks payment with 'Payment cannot exceed outstanding amount' | **PASS** |
| 3.6 | Soft delete customer from Customer screen | Customer hidden from list; Net Due subtracted from Home dashboard | Excluded from list and dashboard calculation | **PASS** |

---

### Journey 4: Offline POS Operations & Synchronization
| Step | Test Action | Expected Result | Actual Result | Status |
| :---: | :--- | :--- | :--- | :---: |
| 4.1 | Disconnect Wi-Fi / LAN | Offline banner appears; client switches to local SQLite | Offline banner renders; SQLite operational | **PASS** |
| 4.2 | Generate bill offline | Bill saved locally in SQLite `tokens` and queued in `sync_queue` | Saved locally with temporary ID | **PASS** |
| 4.3 | Reconnect Wi-Fi / LAN | `SyncService` drains queue to backend | API requests dispatched to backend | **PASS** |
| 4.4 | Reconcile temporary IDs with server IDs | SQLite replaces temp IDs with server PostgreSQL integer IDs | **Response discarded; temp IDs not reconciled** | **FAIL (P1)** |
| 4.5 | Validation error in offline queued item | Queue skips or isolates invalid item | **Queue hangs in infinite retry loop** | **FAIL (P2)** |
| 4.6 | Cashier logs out while offline | Warns cashier of pending unsynced bills | **Wipes `sync_queue` causing permanent data loss** | **FAIL (P0)** |

---

## 3. High-Risk Edge Cases & QA Defect Summary

```
Defect Severity Summary:
├── P0 (Blockers):
│   ├── QA-01: OTP exposed in HTTP API response payload
│   ├── QA-02: Dev Mode bypass allows unauthenticated SuperAdmin takeover
│   └── QA-03: Logout wipes unsynced offline sync queue
│
├── P1 (High):
│   ├── QA-04: Weekly and Monthly reports exclude unpaid Udhar bills (Daily report includes them)
│   ├── QA-05: Tab navigation destroys active cart in Token Generation screen
│   ├── QA-06: Sync engine does not reconcile client SQLite IDs with backend PostgreSQL IDs
│   └── QA-07: Customer list endpoint suffers from N+1 query performance degradation
│
└── P2 (Medium):
    ├── QA-08: Zero Flutter widget or unit tests exist in test/ directory
    ├── QA-09: No auto-refresh interceptor for 24-hour expired JWT access tokens
    └── QA-10: Floating point casting in serializers risks decimal precision drift
```

---

## 4. Recommended QA Test Automation Plan

1. **Flutter Unit & Widget Tests:**
   - Implement unit tests for `CustomerLedger` calculation logic.
   - Implement widget tests for `TokenGenerationScreen` verifying cart preservation and keyboard dismissal.
   - Implement `SyncService` mock tests verifying retry ceilings and queue preservation.
2. **Backend Regression Test Additions:**
   - Add automated test verifying that `DailyReport.total_sales == sum(7 DailyReports) == WeeklyReport.total_sales`.
   - Add test verifying that `TodaySummaryView` sums both fully paid bills and partial Udhar payments.
