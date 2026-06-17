"""
Root URL Configuration — SaaS Billing Application
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView, SpectacularRedocView

urlpatterns = [
    # Admin
    path('admin/', admin.site.urls),

    # API v1
    path('api/v1/auth/',          include('apps.accounts.urls')),
    path('api/v1/subscriptions/', include('apps.subscriptions.urls')),
    path('api/v1/invoices/',      include('apps.invoices.urls')),
    path('api/v1/payments/',      include('apps.payments.urls')),
    path('api/v1/reports/',       include('apps.reports.urls')),

    # API Schema & Docs
    path('api/schema/',           SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/',             SpectacularSwaggerView.as_view(url_name='schema'), name='swagger-ui'),
    path('api/redoc/',            SpectacularRedocView.as_view(url_name='schema'), name='redoc'),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
