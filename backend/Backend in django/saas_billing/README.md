# SaaS Billing Backend — Django

A full-featured SaaS billing backend built with Django & Django REST Framework.

## Features
- **Auth**: JWT login/register, email verification, password reset, role-based access
- **Multi-tenancy**: Organisation model with user roles (Admin, Billing Manager, Member, Viewer)
- **Subscriptions**: Plans, Stripe integration, trial periods, upgrade/downgrade, cancellation
- **Invoices**: Full invoice lifecycle, line items, tax rates, PDF generation, email delivery
- **Payments**: Stripe payment methods, charges, refunds, webhook handling
- **Reports**: Dashboard KPIs, MRR/ARR, revenue charts, churn analytics, top customers
- **Async Tasks**: Celery + Redis for emails, PDF generation, overdue reminders

## Project Structure
```
saas_billing/
├── apps/
│   ├── accounts/        # Users, Orgs, Auth
│   ├── subscriptions/   # Plans, Stripe subscriptions
│   ├── invoices/        # Invoices, Line items, PDF
│   ├── payments/        # Payments, Refunds, Webhooks
│   └── reports/         # Analytics & KPIs
├── saas_billing/        # Django project config
├── requirements.txt
└── .env.example
```

## Quick Start

```bash
# 1. Create virtual environment
python -m venv venv && source venv/bin/activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Copy & fill environment variables
cp .env.example .env

# 4. Create PostgreSQL database
createdb saas_billing_db

# 5. Run migrations
python manage.py migrate

# 6. Create superuser
python manage.py createsuperuser

# 7. Start Django
python manage.py runserver

# 8. Start Celery worker (separate terminal)
celery -A saas_billing worker --loglevel=info

# 9. Start Celery Beat scheduler (separate terminal)
celery -A saas_billing beat --loglevel=info
```

## API Docs
- Swagger UI: http://localhost:8000/api/docs/
- ReDoc:       http://localhost:8000/api/redoc/
- Schema:      http://localhost:8000/api/schema/

## API Endpoints

### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/v1/auth/register/ | Register + create org |
| POST | /api/v1/auth/login/ | Get JWT tokens |
| POST | /api/v1/auth/logout/ | Blacklist refresh token |
| GET  | /api/v1/auth/me/ | Get/update profile |
| POST | /api/v1/auth/change-password/ | Change password |
| POST | /api/v1/auth/password-reset/ | Request reset email |
| POST | /api/v1/auth/password-reset/confirm/ | Confirm reset |

### Subscriptions
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/v1/subscriptions/plans/ | List plans |
| GET/POST | /api/v1/subscriptions/ | Get/create subscription |
| POST | /api/v1/subscriptions/change-plan/ | Upgrade/downgrade |
| POST | /api/v1/subscriptions/cancel/ | Cancel at period end |

### Invoices
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET/POST | /api/v1/invoices/ | List/create invoices |
| GET/PUT/DELETE | /api/v1/invoices/<id>/ | Invoice CRUD |
| POST | /api/v1/invoices/<id>/send/ | Email to customer |
| GET | /api/v1/invoices/<id>/pdf/ | Download PDF |
| POST | /api/v1/invoices/<id>/mark-paid/ | Mark as paid |

### Payments
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/v1/payments/ | List payments |
| POST | /api/v1/payments/pay/ | Charge invoice |
| POST | /api/v1/payments/refunds/create/ | Issue refund |
| POST | /api/v1/payments/webhook/ | Stripe webhook |

### Reports
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/v1/reports/dashboard/ | KPI summary |
| GET | /api/v1/reports/revenue/ | Monthly revenue chart |
| GET | /api/v1/reports/mrr/ | MRR & ARR |
| GET | /api/v1/reports/subscriptions/ | Subscription analytics |
| GET | /api/v1/reports/top-customers/ | Top customers |
