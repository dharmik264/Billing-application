# 05 Multi-Tenancy & Online-Only Verification

## Automated Verifications
- [x] Run `dart analyze` to ensure no compilation errors or unused imports remain after deleting offline sync classes.
- [x] Run `python manage.py check` to ensure Django models and views are valid.
- [x] Run `python manage.py makemigrations` and `migrate` to ensure no pending migrations (verified `shop` FK in Printer model).

## Manual Code Verifications
- [x] Check `dashboard_screen.dart` to verify `StreamBuilder` for `SyncService` is completely removed.
- [x] Check `restaurant_api.dart` to verify `LocalDatabase` fallback is removed from `fetchTokens` and `createToken`.
- [x] Check `backend/tokens/views.py` to verify `shop=Shop.get_shop(request.user)` filter is rigidly applied to `TodaySummaryView`, `KitchenView`, and all other views.
- [x] Check `backend/core/views.py` to verify `user.set_password(phone)` and `user.is_staff=True` are explicitly set during OTP login.

## Status
- [x] Completed
