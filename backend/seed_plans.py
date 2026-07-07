import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_pos.settings')
django.setup()

from core.models import SubscriptionPlan

def seed_plans():
    # 1. Basic Plan
    SubscriptionPlan.objects.get_or_create(
        name="Basic Plan",
        defaults={
            "description": "Suitable for individual users or small businesses. Includes essential features.",
            "price_monthly": 199.00,
            "price_yearly": 1999.00,
            "max_users": 1,
            "max_tables": 0,
            "max_invoices_per_month": 100,
            "features": {
                "billing_access": True,
                "inventory_access": False,
                "reports_access": False,
                "tax_access": False,
                "staff_management": False,
            },
            "is_active": True,
            "is_popular": False,
            "display_order": 1,
        }
    )

    # 2. Professional Plan
    SubscriptionPlan.objects.get_or_create(
        name="Professional Plan",
        defaults={
            "description": "Designed for growing businesses. Includes all Basic Plan features plus advanced tools and higher usage limits.",
            "price_monthly": 499.00,
            "price_yearly": 4999.00,
            "max_users": 5,
            "max_tables": 20,
            "max_invoices_per_month": 1000,
            "features": {
                "billing_access": True,
                "inventory_access": True,
                "reports_access": True,
                "tax_access": True,
                "staff_management": False,
            },
            "is_active": True,
            "is_popular": True,
            "display_order": 2,
        }
    )

    # 3. Enterprise Plan
    SubscriptionPlan.objects.get_or_create(
        name="Enterprise Plan",
        defaults={
            "description": "Intended for large organizations with advanced requirements. Includes custom limits and enterprise-level functionality.",
            "price_monthly": 1999.00,
            "price_yearly": 19999.00,
            "max_users": 50,
            "max_tables": 100,
            "max_invoices_per_month": -1, # Unlimited
            "features": {
                "billing_access": True,
                "inventory_access": True,
                "reports_access": True,
                "tax_access": True,
                "staff_management": True,
            },
            "is_active": True,
            "is_popular": False,
            "display_order": 3,
        }
    )

    print("Plans seeded successfully!")

if __name__ == '__main__':
    seed_plans()
