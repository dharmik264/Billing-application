import os
import django
from datetime import timedelta
from django.utils import timezone

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_pos.settings')
django.setup()

from core.models import User
from shop.models import Shop, BillTemplate
from menu.models import Category, MenuItem


def seed():
    print("=" * 60)
    print("SEEDING SUPER ADMIN, USER, SHOP, AND MENU ITEMS")
    print("=" * 60)

    # 1. Create Super Admin
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

    # 2. Create User / Shop Owner
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

    # 3. Create/Configure Shop attached to User
    shop = Shop.get_shop(user)
    shop.name = "Dharmik Cafe & Restaurant"
    shop.phone = user_phone
    shop.address = "123 Main Street, Near City Center, Ahmedabad"
    shop.upi_id = "dharmik@upi"
    shop.table_count = 10
    shop.save()
    print(f"[SUCCESS] Shop Configured: '{shop.name}'")

    # Ensure Bill Template
    BillTemplate.get_template(shop)

    # 4. Create Categories & 6 Menu Items
    cat_starters, _ = Category.objects.get_or_create(shop=shop, name="Starters", defaults={"icon": "Starters", "sort_order": 1})
    cat_main, _     = Category.objects.get_or_create(shop=shop, name="Main Course", defaults={"icon": "Main", "sort_order": 2})
    cat_beverages, _ = Category.objects.get_or_create(shop=shop, name="Beverages", defaults={"icon": "Beverages", "sort_order": 3})

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
            shop=shop,
            name=item_info["name"],
            defaults=item_info
        )
        if created:
            created_count += 1
        print(f"   * {item.name} ({item.category.name}) -> Rs {item.price}")

    print(f"\n[COMPLETE] Seeded data successfully! Total menu items: {MenuItem.objects.filter(shop=shop).count()}")

if __name__ == '__main__':
    seed()
