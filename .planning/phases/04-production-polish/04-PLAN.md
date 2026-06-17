# Goal: Phase 4 - Production Polish

The goal of this phase is to finalize the Restaurant POS Billing Application for production by resolving build deprecations, improving the UX with loading skeletons, and adding advanced receipt generation features (PDF and Thermal Printing).

## User Review Required

> [!WARNING]
> Migrating Flutter Android plugins (KGP deprecations) requires modifying `android/build.gradle` and updating plugin versions in `pubspec.yaml`. This may cause temporary build instability. I will need to test the build thoroughly after these updates.
> 
> Thermal printing will require adding a new Bluetooth printing package. Do you have a specific Bluetooth thermal printer model in mind, or should I use a generic ESC/POS library?

## Proposed Changes

---

### App Configuration & Build

#### [MODIFY] `android/build.gradle`
- Update the Kotlin version and Android Gradle Plugin (AGP) version to support Built-in Kotlin for plugins.

#### [MODIFY] `pubspec.yaml`
- Upgrade `image_picker`, `shared_preferences`, and `url_launcher` to their latest versions that support Built-in Kotlin to eliminate KGP warnings.
- Add `pdf` and `printing` packages for PDF receipt generation.
- Add `blue_thermal_printer` or `esc_pos_printer` for thermal printer integration.

---

### UX Improvements

#### [NEW] `lib/widgets/skeleton_loader.dart`
- Create a reusable skeleton loader widget with a shimmer effect to display while lists (like items and tokens) are fetching from the backend.

#### [MODIFY] `lib/screens/dashboard_screen.dart`
- Replace hardcoded `CircularProgressIndicator` with the new `SkeletonLoader` when fetching the initial dashboard data.

#### [MODIFY] `lib/screens/item_management_screen.dart`
- Replace the loading spinner with a list of skeleton item cards to improve perceived performance during offline/online data fetching.

---

### Printing & Receipts

#### [NEW] `lib/services/pdf_receipt_service.dart`
- Implement a utility class that takes an `ApiToken` and generates an A4 or 80mm PDF receipt using the `pdf` package.

#### [MODIFY] `lib/services/printer_service.dart`
- Update the existing printer service to support connecting to paired Bluetooth thermal printers and sending ESC/POS raw bytes for the receipt.

#### [MODIFY] `lib/screens/token_generation_screen.dart`
- Add a "Print Receipt" button on the success dialog that triggers the thermal printer or opens the PDF preview.

## Verification Plan

### Automated Tests
- `flutter build apk --release` to verify KGP warnings are entirely resolved and the build succeeds.

### Manual Verification
- Launch the app and verify the shimmer skeleton loaders appear smoothly before data populates.
- Generate a token and attempt to generate a PDF receipt. Verify the layout of the receipt matches the shop settings (Logo, Name, Address).
- Attempt to pair a Bluetooth thermal printer and print a physical receipt (User verification required for hardware).
