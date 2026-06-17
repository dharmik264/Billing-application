# Restaurant POS — Django Backend

Complete REST API backend for the Flutter Restaurant POS app.

## Apps & Endpoints

| App | Base URL | Description |
|-----|----------|-------------|
| core | `/api/auth/` | OTP login, JWT tokens, user profile, app settings |
| shop | `/api/shop/` | Shop setup (singleton) |
| menu | `/api/menu/` | Categories + menu items |
| tokens | `/api/tokens/` | Token/order creation, kitchen, payment |
| reports | `/api/reports/` | Daily / weekly / monthly analytics |
| printer | `/api/printer/` | Printer setup, receipt & kitchen slip printing |

## Quick Start

```bash
# 1. Clone and setup
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt

# 2. Configure environment
cp .env.example .env
# Edit .env with your values

# 3. Run migrations
python manage.py migrate

# 4. Create superuser
python manage.py createsuperuser --phone 9999999999

# 5. Start server
python manage.py runserver

# 6. (Optional) Start Celery worker
celery -A restaurant_pos worker -l info
```

## Key API Endpoints

### Auth
- `POST /api/auth/send-otp/` — Send OTP to phone
- `POST /api/auth/verify-otp/` — Verify OTP → returns JWT tokens
- `POST /api/auth/logout/` — Blacklist refresh token
- `POST /api/auth/token/refresh/` — Refresh access token
- `GET/PATCH /api/auth/profile/` — User profile
- `GET/PATCH /api/auth/settings/` — GST, service charge, currency

### Shop
- `GET/PATCH /api/shop/` — Shop details

### Menu
- `GET/POST /api/menu/categories/` — List / create categories
- `GET/PUT/DELETE /api/menu/categories/<id>/` — Category detail
- `GET/POST /api/menu/items/` — List (filter: category, available, type) / create items
- `GET/PUT/DELETE /api/menu/items/<id>/` — Item detail
- `PATCH /api/menu/items/<id>/toggle/` — Toggle availability
- `GET /api/menu/by-category/` — Full menu grouped by category

### Tokens
- `GET /api/tokens/` — List tokens (filter: status, date, today, is_paid)
- `POST /api/tokens/create/` — Create new token with items
- `GET /api/tokens/<id>/` — Token detail
- `PATCH /api/tokens/<id>/status/` — Update status (open/preparing/ready/completed/cancelled)
- `POST /api/tokens/<id>/add-items/` — Add more items to token
- `POST /api/tokens/<id>/payment/` — Process payment (cash/upi/card)
- `PATCH /api/tokens/<id>/cancel/` — Cancel token
- `GET /api/tokens/kitchen/` — Kitchen display (open + preparing)
- `GET /api/tokens/summary/today/` — Dashboard summary

### Reports
- `GET /api/reports/daily/?date=YYYY-MM-DD` — Daily report
- `GET /api/reports/weekly/` — Last 7 days
- `GET /api/reports/monthly/?year=&month=` — Monthly breakdown
- `GET /api/reports/top-items/?days=7&limit=10` — Top selling items
- `GET /api/reports/categories/?days=7` — Sales by category
- `GET /api/reports/range/?start=YYYY-MM-DD&end=YYYY-MM-DD` — Custom range

### Printer
- `GET/POST /api/printer/printers/` — List / add printers
- `GET/PUT/DELETE /api/printer/printers/<id>/` — Printer detail
- `POST /api/printer/print/receipt/` — Print receipt
- `POST /api/printer/print/kitchen-slip/` — Print kitchen slip
- `GET /api/printer/preview/<token_id>/?type=receipt|kitchen` — Preview
- `GET /api/printer/jobs/` — Print job history

## Project Structure

```
restaurant_pos/
├── core/        # Auth, OTP, User, AppSettings
├── shop/        # Shop profile
├── menu/        # Category, MenuItem
├── tokens/      # Token, TokenItem (billing engine)
├── reports/     # Analytics views
├── printer/     # Printer, PrintJob
└── restaurant_pos/  # settings, urls, celery
```
