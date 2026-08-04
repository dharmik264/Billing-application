import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'restaurant_pos.settings')

application = get_wsgi_application()

# Auto-migrate and seed data if database tables are missing on startup
try:
    from django.db import connection
    from django.core.management import call_command
    tables = connection.introspection.table_names()
    if 'core_user' not in tables or 'core_systemsettings' not in tables or 'core_subscriptionplan' not in tables:
        print("[STARTUP] Missing core database tables. Running auto-migrations and seeding...")
        call_command('migrate', interactive=False)
        try:
            import seed_plans
            if hasattr(seed_plans, 'seed'):
                seed_plans.seed()
        except Exception as e:
            print("[STARTUP] Error running seed_plans:", e)
        try:
            import seed_initial_data
            if hasattr(seed_initial_data, 'seed'):
                seed_initial_data.seed()
        except Exception as e:
            print("[STARTUP] Error running seed_initial_data:", e)
except Exception as e:
    print("[STARTUP] Database check notice:", e)

