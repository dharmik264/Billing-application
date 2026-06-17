import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_pos.settings')
app = Celery('restaurant_pos')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()
