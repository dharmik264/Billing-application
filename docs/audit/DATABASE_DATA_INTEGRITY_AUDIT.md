# Comprehensive Database & Data Integrity Audit Report

**Audit Date:** October 2026  
**Auditor:** Principal Database Architect & Data Integrity Lead  
**Scope:** Data Modeling, Schema Isolation, Decimal Precisions, Foreign Key Constraints, Soft Delete Mechanics, and Accounting Ledger Consistency  
**Databases Analyzed:** PostgreSQL 16 (Production `billing-db` via Render) & SQLite 3 (Development `db.sqlite3` & Client `local_billing.db`)

---

## 1. Database Topology & Multi-Tenancy Architecture

The application implements a hybrid database strategy:
- **Production Engine:** PostgreSQL utilizing `django-tenants` schema-based isolation (`django_tenants.postgresql_backend`).
- **Development/Fallback Engine:** SQLite (`django.db.backends.sqlite3`).
- **Client Offline Storage:** SQLite via `sqflite` / `sqflite_common_ffi` (`local_billing.db`).

### Schema Distribution in PostgreSQL:
```
PostgreSQL Database: billing_app
├── public Schema (SHARED_APPS)
│   ├── core_user                 (Authentication & merchant profiles)
│   ├── shop_shop                 (Tenants, configuration, sms credits)
│   ├── shop_domain               (Tenant routing domains)
│   └── django_celery_beat_*      (Asynchronous background task schedules)
│
└── tenant schemas: e.g. dharmik_shop, shop_xyz (TENANT_APPS)
    ├── menu_category             (Catalog categories)
    ├── menu_menuitem             (Menu items, prices, food types)
    ├── tokens_token              (Orders, tokens, bills, grand totals)
    ├── tokens_tokenitem          (Bill line items)
    ├── customers_customer        (Customer records, GSTIN, soft-delete status)
    ├── customers_customerpayment (Ledger payment transactions & manual adjustments)
    └── printer_printer           (Hardware printer settings)
```

---

## 2. Model Schema & Constraint Analysis

### 2.1 The Customer & Ledger Subsystem (`customers`)
```python
# backend/customers/models.py
class Customer(models.Model):
    name          = models.CharField(max_length=200)
    mobile_number = models.CharField(max_length=20, unique=True)
    address       = models.TextField(blank=True, null=True)
    gst_number    = models.CharField(max_length=15, blank=True, default='')
    status        = models.CharField(max_length=10, choices=[('active', 'Active'), ('inactive', 'Inactive')], default='active')
    created_at    = models.DateTimeField(auto_now_add=True)
    updated_at    = models.DateTimeField(auto_now=True)

class CustomerPayment(models.Model):
    customer       = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name='payments')
    token          = models.ForeignKey('tokens.Token', null=True, blank=True, on_delete=models.SET_NULL, related_name='payments')
    payment_number = models.CharField(max_length=50, blank=True)
    amount         = models.DecimalField(max_digits=10, decimal_places=2)
    payment_mode   = models.CharField(max_length=20, default='cash')
    date           = models.DateField(default=timezone.localdate)
    note           = models.TextField(blank=True)
    created_at     = models.DateTimeField(auto_now_add=True)
```

### Critical Findings in Customer Ledger Modeling:
1. **Unsafe Cascade Deletion on Financial Records (P1):**
   `customer = models.ForeignKey(Customer, on_delete=models.CASCADE)`
   If an administrator or script performs a hard delete on a `Customer`, PostgreSQL cascades and deletes all records in `CustomerPayment`. In an accounting system, financial transaction history must NEVER be cascade-deleted. It must use `on_delete=models.PROTECT` or `on_delete=models.RESTRICT`.
2. **String-Based Phone Relational Join Between Tokens & Customers (P1):**
   - In `Token`, the customer relationship is stored as denormalized strings: `customer_name` and `customer_phone`.
   - In `compute_customer_ledger_summary` ([customers/views.py line 40](file:///d:/DharmikProject/billing%20application/backend/customers/views.py#L40)):
     ```python
     tokens = Token.objects.filter(customer_phone=customer.mobile_number).exclude(status='cancelled')
     ```
   - If a customer changes their mobile number, all past tokens remain tied to the old phone string. The customer's ledger history is severed, and their historical billed amounts disappear from their new ledger.
   - **Recommended Fix:** Add a nullable foreign key `customer = models.ForeignKey(Customer, null=True, blank=True, on_delete=models.SET_NULL)` on `Token`.
3. **Double Database Save Overhead on Every Payment (P2):**
   In [customers/models.py lines 62-66](file:///d:/DharmikProject/billing%20application/backend/customers/models.py#L62-L66):
   ```python
   def save(self, *args, **kwargs):
       super().save(*args, **kwargs) # First DB INSERT
       if not self.payment_number:
           self.payment_number = f"P{self.id:04d}"
           super().save(update_fields=['payment_number']) # Second DB UPDATE
   ```
   Every payment creation forces two sequential database round-trips. This should be generated using a PostgreSQL sequence or formatted in memory before initial insert.

---

### 2.2 Token & Bill Subsystem (`tokens`)
```python
# backend/tokens/models.py
class Token(models.Model):
    token_number    = models.PositiveIntegerField()
    bill_number     = models.CharField(max_length=20, blank=True)
    date            = models.DateField(default=timezone.localdate)
    order_type      = models.CharField(max_length=20, choices=ORDER_TYPE_CHOICES, default='dine_in')
    table_number    = models.CharField(max_length=10, blank=True)
    customer_name   = models.CharField(max_length=100, blank=True)
    customer_phone  = models.CharField(max_length=15, blank=True)
    subtotal        = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    gst_amount      = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    service_charge  = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    discount        = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total           = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    received_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    balance_due     = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    is_paid         = models.BooleanField(default=False)
    payment_mode    = models.CharField(max_length=20, blank=True)
```

### Critical Findings in Token Modeling:
1. **`unique_together = ['token_number', 'date']` Constraint Risk (P2):**
   - Token numbers reset daily (1, 2, 3...).
   - If two cashiers generate bills simultaneously during peak hours or during an offline sync burst, concurrent inserts can violate this uniqueness constraint, causing HTTP 500 crashes unless wrapped in transactional retry blocks with row locking (`select_for_update`).
2. **Denormalized `items_summary` Text Field:**
   `Token.items_summary` stores a comma-separated string of items for rapid display. This helps avoid extra joins when rendering the dashboard list, but if a line item is edited via `AddItemToTokenView`, `items_summary` can become out of sync with actual `TokenItem` records unless explicitly recalculated.

---

## 3. Financial Integrity & Decimal Precision

### 3.1 IEEE 754 Floating-Point Precision Leakage in DRF Serializers (P2)
In [backend/customers/views.py](file:///d:/DharmikProject/billing%20application/backend/customers/views.py#L167,L303):
```python
return Response({
    'total_billed': float(summary['total_billed']),
    'total_paid':   float(summary['total_paid']),
    'net_due':      float(summary['net_due']), # <--- FLOAT CONVERSION
})
```
- In Python, calculations are performed using `Decimal` (e.g., `Decimal('199.99')`).
- However, when serializing responses, the view converts values to Python `float()`.
- Standard IEEE 754 floating-point representations can produce values such as `199.99000000000001` or `0.00000000000004` instead of exact financial decimals.
- **Recommended Practice:** Return strings or DRF `DecimalField` representations formatted to two decimal places (`"199.99"`).

---

## 4. Soft Delete Integrity & Divergence

### Backend vs Frontend Soft Delete Implementation:
1. **Backend (Django):**
   - [CustomerDetailView.perform_destroy](file:///d:/DharmikProject/billing%20application/backend/customers/views.py#L123-L125) executes soft delete:
     ```python
     def perform_destroy(self, instance):
         instance.status = 'inactive'
         instance.save()
     ```
   - [CustomerListCreateView.get_queryset](file:///d:/DharmikProject/billing%20application/backend/customers/views.py#L104) excludes inactive records:
     ```python
     return Customer.objects.exclude(status='inactive')
     ```
   - Data is preserved in the database for auditing and historical financial reconciliation.
2. **Frontend (Local SQLite):**
   - [LocalDatabase.deleteCustomer](file:///d:/DharmikProject/billing%20application/lib/services/local_database.dart#L224-L228):
     ```dart
     Future<void> deleteCustomer(String id) async {
       final db = await instance.database;
       if (db == null) return;
       await db.delete('customers', where: 'id = ?', whereArgs: [id]); // <--- HARD DELETE
     }
     ```
   - The local database drops the customer row entirely. If the client queries local customer history offline, the record is gone, while the backend maintains the row marked `inactive`.
   - **Recommended Fix:** Add a `status TEXT DEFAULT 'active'` column to SQLite `customers` table and execute `UPDATE customers SET status = 'inactive' WHERE id = ?`.

---

## 5. Prioritized Data Integrity Recommendations

| Priority | Issue | Recommended Fix | Target File |
| :---: | :--- | :--- | :--- |
| **P1** | Cascade Delete on Payments | Change `on_delete=models.CASCADE` to `on_delete=models.PROTECT` on `CustomerPayment.customer`. | [customers/models.py](file:///d:/DharmikProject/billing%20application/backend/customers/models.py#L41) |
| **P1** | String Phone Token Join | Add `customer = models.ForeignKey(Customer, null=True, on_delete=models.SET_NULL)` on `Token`. | [tokens/models.py](file:///d:/DharmikProject/billing%20application/backend/tokens/models.py#L28) |
| **P2** | Double Save on `CustomerPayment` | Pre-calculate `payment_number` before initial save using atomic sequence or database ID. | [customers/models.py](file:///d:/DharmikProject/billing%20application/backend/customers/models.py#L62) |
| **P2** | Float Cast in Serializers | Format Decimal fields as strings or DRF `DecimalField` to prevent floating-point inaccuracies. | [customers/views.py](file:///d:/DharmikProject/billing%20application/backend/customers/views.py#L167) |
| **P2** | Local SQLite Hard Delete | Update `LocalDatabase.deleteCustomer` to set `status = 'inactive'` matching Django backend. | [local_database.dart](file:///d:/DharmikProject/billing%20application/lib/services/local_database.dart#L224) |
