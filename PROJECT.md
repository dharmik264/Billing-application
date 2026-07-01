# Restaurant POS & Billing Application

A comprehensive, multi-tenant POS (Point of Sale) and Billing System tailored for restaurants, cafes, and shops. The system offers real-time order tracking, menu item management, shop customization, daily analytics, and direct hardware integration with thermal printers.

---

## 🏗 Architecture & Tech Stack

The application uses a decoupled architecture with a modern mobile-first frontend communicating via REST APIs to a robust backend.

### **Frontend**
- **Framework**: Flutter (Dart)
- **Platforms**: Mobile (Android/iOS) and Web
- **Key Features**: 
  - Token-based Authentication (JWT)
  - OTP Login System
  - Responsive Dashboard
  - Live Token / Kitchen Display
  - Bluetooth/Thermal Printer Integration

### **Backend**
- **Framework**: Django (Python)
- **Database**: SQLite (Default)
- **Key Modules**:
  - `core`: Authentication, OTP login, JWT management, and user settings.
  - `shop`: Multi-tenant shop profile and invoice configurations.
  - `menu`: Dynamic item and category management.
  - `tokens`: Order placement, kitchen tracking, payment states, and billing logic.
  - `reports`: Daily, weekly, and custom analytics views.
  - `printer`: Thermal receipt and kitchen slip generation.

---

## ✨ Core Features

### 1. Order & Token Management
- **Create Orders**: Generate tokens/orders instantly from the POS.
- **Kitchen Tracking**: Track tokens through states (`open` → `preparing` → `ready` → `completed`).
- **Payments**: Support for Split/Cash/UPI/Card payments.
- **Token History**: View all past orders with status filtering.

### 2. Menu & Item Management
- **Categories**: Group items logically.
- **Toggle Availability**: Instantly mark items as out-of-stock.
- **Price Management**: Configure rates and tax rules per item.

### 3. Shop Setup & Customization
- **Branding**: Upload custom Shop Logo and Payment QR Codes.
- **Bill Customization**: Configure what appears on the printed receipt (GST, Customer Details, Shop Address, Custom Footer Notes).

### 4. Live Analytics & Dashboard
- **Daily Summary**: Real-time tracking of Today's Tokens, Total Sales, Cash vs. Online breakdown.
- **Advanced Reports**: Top-selling items, revenue by category, and weekly/monthly charting.

### 5. Hardware Integrations
- **Thermal Printers**: Integration with ESC/POS standard thermal printers via Bluetooth.
- **Print Types**: Separate logic for formatting and printing **Customer Receipts** and **Kitchen Slips**.

---

## 📂 Project Structure

```text
billing_application/
├── android/              # Android native shell
├── ios/                  # iOS native shell
├── lib/                  # Flutter Frontend Source Code
│   ├── main.dart         # Entry point & App routing
│   ├── screens/          # UI Screens (Dashboard, POS, Settings, Auth)
│   └── utils/            # Theme, Constants, API services
├── backend/              # Django Backend Source Code
│   ├── core/             # Auth/Users module
│   ├── menu/             # Catalog management
│   ├── printer/          # Hardware integration logic
│   ├── reports/          # Analytics & Dashboards
│   ├── shop/             # Tenant configuration
│   └── tokens/           # POS Billing Engine
├── pubspec.yaml          # Flutter dependencies
├── requirements.txt      # Python dependencies
└── README.md             # Standard quick-start info
```

---

## 🚀 Setup & Installation

### 1. Backend Setup (Django)

**Prerequisites:** Python 3.9+

```bash
cd backend

# 1. Create and activate a virtual environment
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env
# Edit .env to set up SECRET_KEY and DB configurations

# 4. Run migrations and create a superuser
python manage.py migrate
python manage.py createsuperuser --phone 9999999999

# 5. Start the development server
python manage.py runserver
```
*(The backend runs on `http://127.0.0.1:8000` by default)*

### 2. Frontend Setup (Flutter)

**Prerequisites:** Flutter SDK 3.0+, Dart 3.0+

```bash
# Ensure you are at the project root
cd ..

# 1. Install dependencies
flutter pub get

# 2. Run the application
flutter run
```

*(Ensure the backend is running and the API Base URL in the Flutter app points to your local machine or hosted server).*

---

## 🧪 Testing Credentials

To quickly test the UI layer offline (if dummy data is configured in the frontend):
- **Mobile Number**: `Any 10-digit number` (e.g., 9845012345)
- **OTP**: `4242`

---

## 🔮 Future Enhancements

- **Cloud Deployment**: Containerize (Docker) backend and deploy to scalable infra.
- **Multi-tenant Architecture**: Support multiple isolated branches/franchises.
- **Web Portal**: Dedicated desktop browser view for administrators.
- **Inventory Management**: Track stock depletion based on menu items sold.
