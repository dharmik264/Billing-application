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
                from shop.models import Shop
                shop = getattr(user, 'shop', None) or Shop.get_shop(user)
                if shop and shop.schema_name:
                    connection.set_schema(shop.schema_name)
                    request.tenant = shop
        except Exception as e:
            logger.error(f"Tenant schema middleware error: {e}")
