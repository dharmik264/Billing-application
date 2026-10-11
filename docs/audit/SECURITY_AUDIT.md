# Comprehensive Security Audit Report

**Audit Date:** October 2026  
**Auditor:** Principal Application Security Auditor & Penetration Tester  
**Scope:** Authentication, Authorization, API Security, Cryptography, Multi-Tenancy Isolation, Configuration Hardening, and OWASP Top 10  
**Target:** Flutter Client (Android/iOS/Desktop) & Django REST Framework Backend

---

## 1. Executive Summary & Threat Classification

The security audit revealed **multiple critical vulnerabilities (P0)** that permit complete authentication bypass, administrative account takeover, credential leakage, and data exposure. These vulnerabilities exist in active source code files and production deployment configurations.

### Summary of Vulnerabilities by Severity:
- **P0 (Critical / Exploitable Immediately):** 3 Vulnerabilities
- **P1 (High Risk / Architectural):** 4 Vulnerabilities
- **P2 (Medium Risk / Hardening):** 3 Vulnerabilities
- **P3 (Low Risk / Defense in Depth):** 2 Vulnerabilities

---

## 2. Detailed Vulnerability Findings

### 2.1 [P0] Unauthenticated Developer Backdoor & Account Takeover
- **Vulnerable Files:**
  - [backend/core/urls.py lines 38–39](file:///d:/DharmikProject/billing%20application/backend/core/urls.py#L38-L39)
  - [backend/core/views.py lines 480–525](file:///d:/DharmikProject/billing%20application/backend/core/views.py#L480-L525)
  - [lib/screens/super_admin_login_screen.dart](file:///d:/DharmikProject/billing%20application/lib/screens/super_admin_login_screen.dart)
- **Description:**
  The backend exposes two developer endpoints protected with `permission_classes = [AllowAny]`:
  ```python
  # backend/core/views.py line 480
  class DevUsersView(APIView):
      permission_classes = [AllowAny]
      def get(self, request):
          users = User.objects.all().order_by('-is_superuser', 'name')
          return Response([...]) # Dumps all user IDs, names, phones, roles, is_superuser flags

  # backend/core/views.py line 503
  class DevLoginView(APIView):
      permission_classes = [AllowAny]
      def post(self, request):
          phone = request.data.get('phone')
          user = User.objects.filter(phone=phone).first()
          # Generates and returns valid JWT access and refresh tokens without requiring a password!
          refresh = RefreshToken.for_user(user)
          return Response({'access': str(refresh.access_token), 'refresh': str(refresh)})
  ```
- **Exploitation:**
  Any unauthenticated attacker on the Internet can issue `GET /api/auth/dev/users/` to enumerate all registered merchants and superadmins, pick the superadmin's phone number, and issue `POST /api/auth/dev/login/` with `{"phone": "<superadmin_phone>"}`. The server immediately returns an unrestricted JWT SuperAdmin bearer token.
  The Flutter app even provides a UI toggle in the Super Admin Login screen that performs this exploit in a single tap.
- **Remediation:**
  Completely delete `DevUsersView`, `DevLoginView`, and their route definitions from `core/urls.py`. Strip the developer mode card from `super_admin_login_screen.dart`.

---

### 2.2 [P0] OTP Leakage in HTTP API Responses
- **Vulnerable Files:**
  - [backend/core/views.py lines 144–146, 172–174](file:///d:/DharmikProject/billing%20application/backend/core/views.py#L144,L172)
  - [render.yaml lines 28–29](file:///d:/DharmikProject/billing%20application/render.yaml#L28-L29)
- **Description:**
  In `SendOTPView` and `RegisterView`:
  ```python
  if settings.DEBUG or getattr(settings, 'RETURN_OTP_IN_RESPONSE', False):
      response_data['otp'] = code
  ```
  In [render.yaml](file:///d:/DharmikProject/billing%20application/render.yaml#L28-L29), the production environment configuration specifies:
  ```yaml
  - key: RETURN_OTP_IN_RESPONSE
    value: "True"
  ```
- **Exploitation:**
  When any user requests an OTP to log in or reset a password via `/api/auth/send-otp/`, the 6-digit OTP code is returned directly in the JSON response payload. Any client or intermediary can read the OTP from the HTTP response without having access to the victim's physical SIM card or SMS gateway.
- **Remediation:**
  Set `RETURN_OTP_IN_RESPONSE = False` in production configurations and remove `response_data['otp'] = code` from production builds.

---

### 2.3 [P0] Hardcoded Credentials Re-Seeded on Every Deployment
- **Vulnerable Files:**
  - [backend/seed_initial_data.py lines 40–79](file:///d:/DharmikProject/billing%20application/backend/seed_initial_data.py#L40-L79)
  - [backend/build.sh line 9](file:///d:/DharmikProject/billing%20application/backend/build.sh#L9)
- **Description:**
  `build.sh` runs `python seed_initial_data.py` on every deployment.
  Lines 40–79 create or update users with static, publicly visible credentials:
  - Super Admin: Phone `6351559728`, Password `Admin123`
  - Tenant Admin: Phone `9845012345`, Password `UserPassword123`
- **Exploitation:**
  If an administrator modifies their password in production, the next deployment automatically reverts their password back to `Admin123`.
- **Remediation:**
  Remove `seed_initial_data.py` from `build.sh`. Move initial bootstrapping to a manual, one-time management command guarded by environment variables.

---

### 2.4 [P1] Hardcoded Phone-Based Client Routing Bypass
- **Vulnerable File:**
  - [lib/main.dart line 161](file:///d:/DharmikProject/billing%20application/lib/main.dart#L161)
- **Description:**
  In the Flutter splash screen:
  ```dart
  if (loginPhone == '9999999999') {
    Navigator.pushReplacementNamed(context, '/super-admin-dashboard');
  }
  ```
- **Exploitation:**
  Client-side authorization gating based on a magic phone number string (`'9999999999'`) rather than evaluating cryptographic claims or user roles inside the verified JWT payload (`role == 'super_admin'`).
- **Remediation:**
  Remove the hardcoded phone check. Decode the JWT claims or query `/api/auth/profile/` to determine the user's validated role.

---

### 2.5 [P1] Hardcoded `DEBUG = True` and Wildcard CORS in Production
- **Vulnerable File:**
  - [backend/restaurant_pos/settings.py lines 11, 23, 25](file:///d:/DharmikProject/billing%20application/backend/restaurant_pos/settings.py#L11)
  - [render.yaml lines 23–25](file:///d:/DharmikProject/billing%20application/render.yaml#L23-L25)
- **Description:**
  ```python
  # settings.py line 11
  DEBUG = True
  # line 13
  ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', '*').split(',')
  ```
  In [render.yaml](file:///d:/DharmikProject/billing%20application/render.yaml#L23-L25):
  ```yaml
  - key: ALLOWED_HOSTS
    value: "*"
  - key: CORS_ALLOWED_ORIGINS
    value: "*"
  ```
- **Impact:**
  - `DEBUG = True` in production leaks full Python stack traces, local variables, database connection strings, and server environment variables on any unhandled exception.
  - Wildcard `ALLOWED_HOSTS = "*"` allows HTTP Host header poisoning attacks.
  - Wildcard `CORS_ALLOWED_ORIGINS = "*"` with credentials enables Cross-Origin Resource Sharing attacks from malicious web pages.
- **Remediation:**
  Set `DEBUG = False`, restrict `ALLOWED_HOSTS` to the production domain, and restrict `CORS_ALLOWED_ORIGINS` to trusted web client origins.

---

### 2.6 [P2] Insecure Client-Side Token Storage
- **Vulnerable File:**
  - [lib/services/restaurant_api.dart lines 58–60](file:///d:/DharmikProject/billing%20application/lib/services/restaurant_api.dart#L58-L60)
- **Description:**
  JWT Access and Refresh tokens are persisted in plain text via `shared_preferences`.
- **Impact:**
  Physical device theft, local backup extraction, or unauthorized file access on rooted Android or shared desktop operating systems can compromise active tokens.
- **Remediation:**
  Migrate to `flutter_secure_storage` to encrypt tokens via platform keychains.

---

## 3. OWASP Top 10 (2021) Compliance Matrix

| OWASP Category | Application Status | Primary Risk / Defect |
| :--- | :---: | :--- |
| **A01: Broken Access Control** | **FAIL (P0)** | Unauthenticated Dev login endpoints allow full account takeover. |
| **A02: Cryptographic Failures** | **FAIL (P1)** | Plaintext token storage in `shared_preferences`; fallback secret key. |
| **A03: Injection** | **PASS** | Django ORM parameterized queries prevent SQL injection across models. |
| **A04: Insecure Design** | **FAIL (P1)** | Lack of rate limiting on OTP generation endpoints. |
| **A05: Security Misconfiguration**| **FAIL (P0)** | Hardcoded `DEBUG = True`, `RETURN_OTP_IN_RESPONSE = True`, Wildcard CORS. |
| **A06: Vulnerable Components** | **PASS** | Django 5.x and DRF 3.15 up-to-date with no known CVEs. |
| **A07: Identification & Auth Failures**| **FAIL (P0)** | Hardcoded superadmin passwords seeded on every build (`Admin123`). |
| **A08: Software & Data Integrity**| **FAIL (P1)** | `build.sh` executes unverified seed scripts during production deployment. |
| **A09: Security Logging & Monitoring**| **WARN (P2)** | Tenant middleware catches all exceptions without structured security alerts. |
| **A10: SSRF** | **PASS** | No arbitrary external URL fetching endpoints exposed to users. |

---

## 4. Prioritized Security Remediation Roadmap

```mermaid
graph TD
    A[Phase 1: Immediate Lockdown (P0)] --> B[Phase 2: Configuration & Auth (P1)]
    B --> C[Phase 3: Storage & Hardening (P2)]

    A1[Delete /api/auth/dev/* Endpoints] --> A
    A2[Disable RETURN_OTP_IN_RESPONSE] --> A
    A3[Remove seed_initial_data.py from build.sh] --> A

    B1[Set DEBUG=False & Restrict CORS/Hosts] --> B
    B2[Enforce Role Evaluation over Phone Check in main.dart] --> B
    B3[Add django-ratelimit on /send-otp/] --> B

    C1[Migrate SharedPreferences to flutter_secure_storage] --> C
    C2[Implement Automated Token Refresh Interceptor] --> C
```
