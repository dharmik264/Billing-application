from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/',    include('core.urls')),
    path('api/shop/',    include('shop.urls')),
    path('api/menu/',    include('menu.urls')),
    path('api/tokens/',  include('tokens.urls')),
    path('api/reports/', include('reports.urls')),
    path('api/printer/',   include('printer.urls')),
    path('api/customers/', include('customers.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
