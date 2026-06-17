"""
accounts/tasks.py — Celery async tasks
"""
from celery import shared_task
from django.core.mail import send_mail
from django.conf import settings


@shared_task(name='accounts.send_verification_email')
def send_verification_email(user_id):
    from .models import User, EmailVerificationToken
    try:
        user  = User.objects.get(id=user_id)
        token = EmailVerificationToken.objects.filter(user=user, is_used=False).latest('created_at')
        link  = f"{settings.FRONTEND_URL}/verify-email/{token.token}"
        send_mail(
            subject='Verify your email',
            message=f'Click to verify: {link}',
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
        )
    except Exception as e:
        raise e


@shared_task(name='accounts.send_password_reset_email')
def send_password_reset_email(user_id, token_str):
    from .models import User
    try:
        user = User.objects.get(id=user_id)
        link = f"{settings.FRONTEND_URL}/reset-password/{token_str}"
        send_mail(
            subject='Reset your password',
            message=f'Click to reset: {link}',
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
        )
    except Exception as e:
        raise e
