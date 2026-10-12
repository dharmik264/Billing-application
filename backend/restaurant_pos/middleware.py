from django.utils.deprecation import MiddlewareMixin
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, AuthenticationFailed
from django_tenants.utils import get_public_schema_name, get_tenant_model
from django.db import connection
import logging

logger = logging.getLogger(__name__)

class JWTAuthenticationTenantMiddleware(MiddlewareMixin):
    """
    Middleware that extracts the JWT token from the Authorization header,
    authenticates the user, and sets the tenant schema based on the user's Shop.
    If no token is provided or authentication fails, it routes to the public schema.
    """
    def process_request(self, request):
        public_schema = get_public_schema_name()
        connection.set_schema(public_schema)
        request.tenant = None

        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return

        jwt_authenticator = JWTAuthentication()
        try:
            # Parse the token
            validated_token = jwt_authenticator.get_validated_token(auth_header.split(' ')[1])
            user = jwt_authenticator.get_user(validated_token)
            
            if user:
                request.user = user
                
                # Check 7-day trial expiration / application lock
                is_super = getattr(user, 'is_superuser', False) or user.phone in ['9999999999', '6351559728']
                if not is_super:
                    allowed_endpoints = (
                        '/api/auth/logout/',
                        '/api/auth/profile/',
                        '/api/auth/plans/',
                        '/api/plans/',
                        '/api/auth/subscriptions/pay/',
                        '/api/subscriptions/pay/',
                        '/api/auth/system-settings/',
                        '/api/system-settings/',
                        '/api/auth/token/refresh/',
                    )
                    path = request.path
                    if not any(path.startswith(ep) for ep in allowed_endpoints):
                        if not user.can_login:
                            from django.http import JsonResponse
                            return JsonResponse({
                                'error': 'Your 7-day free trial has expired. Application is locked.',
                                'code': 'TRIAL_EXPIRED',
                                'detail': 'Your 7-day free trial has expired. Application is locked.',
                                'account_status': 'expired'
                            }, status=403)

                from shop.models import Shop
                shop = None
                try:
                    shop = user.shop
                except Exception:
                    shop = Shop.objects.filter(owner=user).first()

                if not shop:
                    try:
                        shop = Shop.get_shop(user)
                    except Exception as err:
                        logger.error(f"Error in Shop.get_shop for user {user.id}: {err}")

                if shop and shop.schema_name:
                    connection.set_schema(shop.schema_name)
                    request.tenant = shop
        except Exception as e:
            logger.error(f"Tenant schema middleware error: {e}")
