# Future Scalability: Plan & Subscription Settings

This document outlines the roadmap and architecture for making the **Plan Setting Page** (Subscription Management) scalable, dynamic, and automated for the Billing Application.

Currently, user permissions and plans (Trial, Free, Pro) are managed manually by the Super Admin. As the application scales, this process must become automated and highly configurable.

## 1. Dynamic Plan Management (Super Admin)
Instead of hardcoding "Basic" or "Pro" plans in the code, plans should be fully dynamic and configurable from the backend.

### Database Architecture
Introduce a `SubscriptionPlan` model:
- `name` (e.g., "Pro Plan", "Enterprise")
- `price_monthly` / `price_yearly`
- `max_users` (Staff members allowed)
- `max_tables` (For dining/restaurant mode)
- `max_invoices_per_month`
- `features` (JSON field linked directly to the new `permissions` toggle system)
- `is_active` (To hide deprecated plans without deleting them)

### Super Admin UI
- **Plan Builder:** A UI to create, edit, or disable plans.
- **Granular Permissions:** When a Super Admin creates a plan, they check off which modules (Billing, Inventory, Reports) are included. When a user buys this plan, those permissions are automatically applied to their account.

## 2. Automated Billing & Payment Gateway
To scale, we must remove the manual "Shop Request" approval bottleneck for paid users.

### Integration
- **Payment Gateway:** Integrate Razorpay or Stripe for automated subscription payments.
- **Webhooks:** Listen for successful payments (`payment.captured` or `invoice.paid`). Upon success:
  1. Auto-update the user's `account_status` to `approved`.
  2. Auto-assign the purchased plan's `permissions`.
  3. Extend the `trial_end` or `subscription_end` date.

### Invoicing
- Automatically generate a GST-compliant tax invoice for the shop owner whenever they pay for a subscription.

## 3. User-Facing "My Plan" Page
Shop owners need a self-service portal within the app to manage their subscriptions.

### UI Components
- **Current Usage Dashboard:** Visual progress bars showing usage against plan limits (e.g., "800 / 1000 Invoices Generated").
- **Upgrade/Downgrade Flows:** Side-by-side comparison tables of available plans with a direct "Upgrade Now" button.
- **Billing History:** A list of past payments where users can download their subscription invoices.

## 4. Trial, Expiry, and Grace Periods
- **Automated Expiry:** A cron job (e.g., Celery or Django custom management command) that runs daily at midnight to check for expired subscriptions.
- **Grace Period:** If a plan expires, automatically switch the user to a "Read-Only" permission state for 7 days before fully locking the account.
- **Notifications:** Integrate Email/SMS/Push notifications to alert users 7 days, 3 days, and 1 day before their plan expires.

## 5. Add-Ons Architecture
Instead of forcing users into a higher tier, allow modular add-ons.
- **Example:** A user is on the "Basic Plan" but wants to buy the "Inventory Add-on" for ₹200/month.
- **Implementation:** The `permissions` JSON field seamlessly supports this. The backend will simply toggle `"inventory": true` upon purchase, independent of their base plan.

---
**Summary for Implementation Phase:**
When implementing this in the future, start by creating the `SubscriptionPlan` Django model, then build the Super Admin UI for it. Finally, link the Razorpay API to automate the permission assignment logic that was recently built.
