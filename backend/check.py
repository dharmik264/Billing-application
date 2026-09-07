import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_pos.settings')
django.setup()
from django.db import connection
with connection.cursor() as cursor:
    cursor.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'core_user' AND table_schema = 'public';")
    columns = [row[0] for row in cursor.fetchall()]
    print('Columns in core_user:', columns)
