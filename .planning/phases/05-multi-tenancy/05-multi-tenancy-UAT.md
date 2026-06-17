# 05 Multi-Tenancy & Online-Only UAT

## Features to Test
1. **Multi-Tenancy Isolation:** Verify that different users logging in see only their own shop's data (tokens, categories, items).
2. **Online Only Operations:** Verify that offline sync UI is gone and operations fail gracefully when offline.
3. **Admin Panel Access:** Verify that a user can log into the Django admin panel using their mobile number as both username and password after logging into the app.

## UAT Checklist
- [x] Log in with User A's mobile number, create categories, menu items, and tokens.
- [x] Log out and log in with User B's mobile number. Verify User A's data is NOT visible.
- [ ] Turn off the internet on the device, attempt to generate a bill, and observe the network error (ensuring it doesn't queue offline).
- [ ] Verify that the Dashboard and Settings screens do not show any "Pending Sync" or "Backup / Restore" indicators.
- [ ] Go to the Django Admin URL (`/admin/`) and log in using User A's mobile number as both the username and password.

## Status
- [ ] Pending
