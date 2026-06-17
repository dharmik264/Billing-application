import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_pos.settings')
django.setup()

from core.models import User
from shop.models import Shop
from menu.models import Category
from rest_framework.test import APIClient

print("--- Starting Multi-Tenancy UAT Test ---")

# Setup users
user_a, _ = User.objects.get_or_create(phone='6351559728')
user_b, _ = User.objects.get_or_create(phone='9825723837')

client_a = APIClient()
client_a.force_authenticate(user=user_a)

client_b = APIClient()
client_b.force_authenticate(user=user_b)

# Clear existing categories for these shops just in case
shop_a = Shop.get_shop(user_a)
shop_b = Shop.get_shop(user_b)
Category.objects.filter(shop=shop_a).delete()
Category.objects.filter(shop=shop_b).delete()

# User A creates a category
response = client_a.post('/api/menu/categories/', {'name': 'User A Pizza Category'})
if response.status_code == 201:
    print("User A successfully created a category.")
else:
    print("Failed to create category for User A:", response.data)

# User B fetches categories
response_b = client_b.get('/api/menu/categories/')
categories_b = response_b.json()

if categories_b.get("count", 0) == 0:
    print("SUCCESS: User B cannot see User A's category. Multi-Tenancy Isolation is WORKING.")
else:
    print("FAILED: User B saw categories:", categories_b)
