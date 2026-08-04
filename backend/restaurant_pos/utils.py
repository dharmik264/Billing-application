import logging
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status

logger = logging.getLogger(__name__)

def custom_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is None:
        # Unexpected server error caught
        logger.error(f"Unhandled Exception: {str(exc)}", exc_info=exc)
        return Response(
            {
                'error': 'An internal server error occurred.',
                'detail': str(exc)
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
    return response
