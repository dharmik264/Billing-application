# Restaurant POS Billing Application

## What This Is

A fast, responsive, and reliable Point of Sale (POS) and Billing Application tailored for restaurants and shops. It operates with a mobile app frontend (Flutter) and a localized backend (Django/Python) to manage menu items, generate tokens/bills, and handle payments (Cash/Online). It supports seamless offline token generation and high-performance UI rendering for smooth physical device usage.

## Core Value

Ensure 60+ FPS high-performance billing and token generation, even on slow networks or when the local network connection drops, to guarantee that business operations never halt.

## Requirements

### Completed (v1.0)

- [x] Basic Flutter UI setup with theme and layout
- [x] Django backend models and API for Items, Shop Settings, and Tokens
- [x] High-performance rendering for tokens and items using `ListView.builder`
- [x] Configurable local network base URL handling (`RestaurantApi`)
- [x] Offline fallback bypass for Shop Setup and Login when backend is unreachable
- [x] Consolidate full offline synchronization logic (Sync pending offline tokens when backend reconnects)
- [x] Implement advanced error handling and visual indicators for "Online" vs "Offline" modes
- [x] Migrate deprecated Kotlin Gradle Plugins (`image_picker`, `shared_preferences`)
- [x] PDF Receipt generation and Skeleton Loaders

### Current State
**v1.0 MVP Shipped**: Offline-first billing, receipt generation, local django backend integration, and skeleton loader UX is complete.

### Out of Scope

- Cloud-only synchronization without local network support — (Must support local Wi-Fi router isolation).
- Third-party payment gateway integration (like Razorpay) — (Currently relies on manual UPI verification via QR code).

## Context

- **Frontend:** Flutter/Dart (Targeting Android Physical Devices for production).
- **Backend:** Django/Python (Running locally on a laptop, exposing API over local Wi-Fi on port 8000).
- **Network Constraints:** Frequent `TimeoutExceptions` or `No route to host` due to Wi-Fi AP Isolation or Mobile Data overriding local Wi-Fi. The app must be resilient to these network failures.

## Constraints

- **Performance**: Must maintain 60FPS UI rendering. Avoid `SingleChildScrollView` for large lists.
- **Connectivity**: Must allow 0-second or fast failovers to offline modes so the user never has to wait for a spinning loader during network issues.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Reduced `RestaurantApi` timeout to 0 seconds | To force instant failovers in case of local network issues | ✓ Good (User preferred instant offline bypass) |
| Allowed offline bypass in `ShopSetupScreen` | To prevent the user from getting stuck during onboarding when the backend is unreachable | ✓ Good |

---
*Last updated: 2026-06-13 after optimizing API timeouts*
