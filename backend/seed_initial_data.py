import os
import django
from datetime import timedelta
from django.utils import timezone

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_pos.settings')
django.setup()

from core.models import User
from shop.models import Shop, Domain, BillTemplate
from menu.models import Category, MenuItem
from django.db import connection

def seed():
    print("=" * 60)
    print("SEEDING SUPER ADMIN, USER, SHOP (TENANT), AND MENU ITEMS")
    print("=" * 60)

    # 1. Ensure public tenant exists
    public_tenant, created = Shop.objects.get_or_create(
        schema_name='public',
        defaults={
            'name': 'Public Tenant',
            'phone': '0000000000',
        }
    )
    
    if created:
        Domain.objects.get_or_create(
            domain='localhost',
            tenant=public_tenant,
            is_primary=True
        )
        print("[SUCCESS] Public tenant and domain created.")

    # Must stay in public schema for Users because User model is shared
    connection.set_schema('public')

    # 2. Create Super Admin
    admin_phone = "6351559728"
    admin_user, created_admin = User.objects.get_or_create(
        phone=admin_phone,
        defaults={
            "name": "Super Admin",
            "email": "admin@billingapp.com",
            "shop_name": "Headquarters",
            "account_status": "approved",
            "is_staff": True,
            "is_superuser": True,
            "is_active": True,
        }
    )
    admin_user.set_password("Admin123")
    admin_user.is_staff = True
    admin_user.is_superuser = True
    admin_user.account_status = "approved"
    admin_user.is_active = True
    admin_user.save()
    print(f"[SUCCESS] Super Admin Created/Updated: Phone={admin_phone}, Password=Admin123")

    # 3. Create User / Shop Owner
    user_phone = "9845012345"
    user, created_user = User.objects.get_or_create(
        phone=user_phone,
        defaults={
            "name": "Dharmik Patel",
            "email": "dharmik@example.com",
            "shop_name": "Dharmik Cafe & Restaurant",
            "account_status": "approved",
            "trial_start": timezone.now(),
            "trial_end": timezone.now() + timedelta(days=365),
            "is_active": True,
        }
    )
    user.set_password("UserPassword123")
    user.account_status = "approved"
    user.is_active = True
    user.save()
    print(f"[SUCCESS] Shop Owner User Created/Updated: Phone={user_phone}, Password=UserPassword123")

    # 4. Create/Configure Shop attached to User
    shop, shop_created = Shop.objects.get_or_create(
        schema_name='dharmik_shop',
        defaults={
            'name': "Dharmik Cafe & Restaurant",
            'phone': user_phone,
            'address': "123 Main Street, Near City Center, Ahmedabad",
            'upi_id': "dharmik@upi",
            'table_count': 10
        }
    )
    
    if shop_created:
        Domain.objects.get_or_create(
            domain='dharmik_shop.localhost',
            tenant=shop,
            is_primary=True
        )

    # Link user to shop
    user.shop = shop
    user.save()

    print(f"[SUCCESS] Shop Configured (Tenant: {shop.schema_name}): '{shop.name}'")

    # Connect to the tenant's schema to seed tenant-specific data
    connection.set_schema(shop.schema_name)

    # Ensure Bill Template
    BillTemplate.get_template(shop)

    # 5. Create Categories & 6 Menu Items
    cat_starters, _ = Category.objects.get_or_create(name="Starters", defaults={"icon": "Starters", "sort_order": 1})
    cat_main, _     = Category.objects.get_or_create(name="Main Course", defaults={"icon": "Main", "sort_order": 2})
    cat_beverages, _ = Category.objects.get_or_create(name="Beverages", defaults={"icon": "Beverages", "sort_order": 3})

    items_data = [
        {
            "name": "Paneer Butter Masala",
            "category": cat_main,
            "price": 240.00,
            "item_type": "veg",
            "description": "Rich & creamy paneer cooked in cashew and tomato gravy.",
            "is_featured": True,
        },
        {
            "name": "Cheese Butter Masala",
            "category": cat_main,
            "price": 260.00,
            "item_type": "veg",
            "description": "Delicious cheese cubes in smooth tomato butter gravy.",
            "is_featured": True,
        },
        {
            "name": "Butter Naan",
            "category": cat_main,
            "price": 45.00,
            "item_type": "veg",
            "description": "Soft clay oven bread brushed with fresh butter.",
            "is_featured": False,
        },
        {
            "name": "Veg Manchurian Dry",
            "category": cat_starters,
            "price": 180.00,
            "item_type": "veg",
            "description": "Crispy vegetable balls tossed in spicy Indo-Chinese sauce.",
            "is_featured": True,
        },
        {
            "name": "Masala Dosa",
            "category": cat_starters,
            "price": 120.00,
            "item_type": "veg",
            "description": "Crispy rice crepe stuffed with spiced potato filling.",
            "is_featured": False,
        },
        {
            "name": "Cold Coffee with Ice Cream",
            "category": cat_beverages,
            "price": 90.00,
            "item_type": "veg",
            "description": "Thick blended cold coffee topped with vanilla ice cream.",
            "is_featured": True,
        },
    ]

    created_count = 0
    for item_info in items_data:
        item, created = MenuItem.objects.get_or_create(
            name=item_info["name"],
            defaults=item_info
        )
        if created:
            created_count += 1
        print(f"   * {item.name} ({item.category.name}) -> Rs {item.price}")

    print(f"\n[COMPLETE] Seeded data successfully! Total menu items: {MenuItem.objects.count()}")

if __name__ == '__main__':
    seed()
