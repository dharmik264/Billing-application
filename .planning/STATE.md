# Project State

This document captures the current operating state and context of the project.

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-06-13)

**Core value:** High-performance offline-first token generation and billing.
**Current focus:** Phase 6 complete. Ready for new milestone or features.

## Current Status

- **Frontend Build Status:** Releasing successfully. Latest `app-release.apk` builds in ~60 seconds with no fatal errors (KGP warnings exist but are non-blocking).
- **Backend Status:** Django server running locally on `0.0.0.0:8000`. Port 8000 is explicitly allowed in Windows Firewall.
- **Network Status:** Physical Android devices may struggle to connect to the laptop if Mobile Data is on or if AP Isolation is active on the Wi-Fi router. The API timeout is currently configured to `0 seconds` to ensure a strict offline-first bypass.

## Active Workstreams

1. Bypassing network blockage on real mobile devices to provide a completely fluid offline experience (Done).
2. Future: Actually capturing and persisting token data when offline so it can be synced later.

## Recent Decisions

- Set `Duration timeout = const Duration(seconds: 0)` in `RestaurantApi` to explicitly block waiting for network requests, providing a 0-second instant fallback.
- Allowed `shop_setup_screen.dart` to navigate forward if `saveShop` fails, generating an orange warning snackbar instead of blocking the user setup flow.

## Accumulated Context

### Roadmap Evolution
- Phase 6 added: Generate Dynamic UPI QR Code on Bill with Fixed Non-Editable Amount

