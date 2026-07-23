from rest_framework import status, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken
from django.utils import timezone
from datetime import timedelta
from django.db.models import Sum

from .models import User, OTP, AppSettings, SubscriptionPlan
from .serializers import SendOTPSerializer, VerifyOTPSerializer, UserSerializer, AppSettingsSerializer, RegisterSerializer, SubscriptionPlanSerializer
from shop.models import Shop
from tokens.models import Token
from django.contrib.auth import authenticate
import os
import requests
import logging

logger = logging.getLogger(__name__)

def send_sms_otp(phone, code):
    """
    Sends an OTP via a configured SMS gateway.
    Falls back to console print in local development if no API key is provided.
    """
    sms_url = os.getenv('SMS_API_URL')
    sms_key = os.getenv('SMS_API_KEY')
    
    if sms_url and sms_key:
        try:
            # Standard DLT-compliant format
            template = os.getenv('SMS_DLT_TEMPLATE', 'Your verification code is {code}. Please do not share this with anyone.')
            message = template.replace('{code}', str(code))
            
            payload = {
                "route": "otp",
                "variables_values": str(code),
                "message": message,
                "numbers": str(phone),
            }
            headers = {
                "authorization": sms_key,
                "Content-Type": "application/json"
            }
            response = requests.post(sms_url, json=payload, headers=headers, timeout=5)
            response.raise_for_status()
            logger.info(f"OTP sent to {phone} via SMS.")
        except Exception as e:
            logger.error(f"Failed to send SMS to {phone}: {str(e)}")
    else:
        # Development fallback
        print(f"\n{'='*45}")
        print(f"DEVELOPMENT OTP FOR {phone}: {code}")
        print(f"{'='*45}\n")


class PasswordLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone = request.data.get('phone')
        password = request.data.get('password')

        user = authenticate(username=phone, password=password)
        if user is None:
            return Response({'error': 'Invalid mobile number or password'}, status=status.HTTP_401_UNAUTHORIZED)
            
        if not user.can_login:
            return Response({'error': 'Your account is pending approval or inactive.'}, status=status.HTTP_403_FORBIDDEN)
            
        refresh = RefreshToken.for_user(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': UserSerializer(user).data
        }, status=status.HTTP_200_OK)



class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        phone = serializer.validated_data['phone']
        name = serializer.validated_data['name']
        email = serializer.validated_data.get('email', '')
        shop_name = serializer.validated_data['shop_name']
        
        if User.objects.filter(phone=phone).exists():
            return Response({'error': 'Phone number already registered'}, status=status.HTTP_400_BAD_REQUEST)
            
        now = timezone.now()
        trial_end = now + timedelta(days=7)
        user = User.objects.create(
            phone=phone,
            name=name,
            email=email,
            shop_name=shop_name,
            account_status='trial',
            trial_start=now,
            trial_end=trial_end
        )
        password = serializer.validated_data['password']
        user.set_password(password)
        user.save()
        
        Shop.objects.create(owner=user, name=shop_name, email=email, phone=phone)
        
        code = OTP.generate_code()
        OTP.objects.create(phone=phone, code=code)
        
        send_sms_otp(phone, code)
        
        response_data = {'message': 'Registration successful, OTP sent', 'phone': phone}
        if __import__('django.conf', fromlist=['settings']).settings.DEBUG:
            response_data['otp'] = code
            
        return Response(response_data, status=status.HTTP_201_CREATED)

class SendOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = SendOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data['phone']

        # Check if user exists
        if not User.objects.filter(phone=phone).exists():
            return Response({'error': 'Please register first'}, status=status.HTTP_400_BAD_REQUEST)

        # Invalidate old OTPs
        OTP.objects.filter(phone=phone, is_used=False).update(is_used=True)

        code = OTP.generate_code()
        OTP.objects.create(phone=phone, code=code)

        send_sms_otp(phone, code)

        # For dev, return OTP in response if DEBUG is True
        response_data = {'message': 'OTP sent successfully', 'phone': phone}
        if __import__('django.conf', fromlist=['settings']).settings.DEBUG:
            response_data['otp'] = code  # Remove in production!

        return Response(response_data, status=status.HTTP_200_OK)


class VerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data['phone']
        code  = serializer.validated_data['code']

        try:
            otp = OTP.objects.filter(phone=phone, code=code, is_used=False).latest('created_at')
            if otp.is_expired():
                return Response({'error': 'OTP has expired'}, status=status.HTTP_400_BAD_REQUEST)
            otp.is_used = True
            otp.save()
        except OTP.DoesNotExist:
            return Response({'error': 'Invalid OTP'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = User.objects.get(phone=phone)
        except User.DoesNotExist:
            return Response({'error': 'Please register first'}, status=status.HTTP_400_BAD_REQUEST)

        if not user.can_login:
            return Response({'error': 'Trial expired or account not approved'}, status=status.HTTP_403_FORBIDDEN)
        
        # Grant admin panel access
        user.is_staff = True
        user.save()
        
        refresh = RefreshToken.for_user(user)

        return Response({
            'access':  str(refresh.access_token),
            'refresh': str(refresh),
            'user':    UserSerializer(user).data,
        }, status=status.HTTP_200_OK)


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data.get('refresh')
            token = RefreshToken(refresh_token)
            token.blacklist()
        except Exception:
            pass
        return Response({'message': 'Logged out successfully'}, status=status.HTTP_200_OK)


class ProfileView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = UserSerializer

    def get_object(self):
        return self.request.user


class AppSettingsView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = AppSettingsSerializer

    def get_object(self):
        from shop.models import Shop
        shop = Shop.get_shop(self.request.user)
        return AppSettings.get_settings(shop)


class ShopRequestsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not request.user.is_staff and not request.user.phone == '9999999999':
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
        
        users = User.objects.filter(account_status__in=['pending', 'trial']).order_by('-created_at')
        return Response(UserSerializer(users, many=True).data, status=status.HTTP_200_OK)


class ShopRequestActionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, user_id):
        if not request.user.is_staff and not request.user.phone == '9999999999':
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
            
        action = request.data.get('action') # 'approve' or 'decline'
        plan = request.data.get('plan', '')
        
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
            
        if action == 'approve':
            user.account_status = 'approved'
            user.approved_plan = plan
            user.approved_at = timezone.now()
            
            if plan:
                from .models import SubscriptionPlan
                plan_obj = SubscriptionPlan.objects.filter(name__iexact=plan).first()
                if not plan_obj and str(plan).isdigit():
                    plan_obj = SubscriptionPlan.objects.filter(id=int(plan)).first()
                if plan_obj and plan_obj.features:
                    perms = user.permissions or {}
                    for k, v in plan_obj.features.items():
                        perms[k] = v
                    user.permissions = perms
            
            user.save()
            return Response({'message': 'Shop approved successfully and plan features activated'}, status=status.HTTP_200_OK)
        elif action == 'decline':
            user.account_status = 'rejected'
            user.save()
            return Response({'message': 'Shop request declined'}, status=status.HTTP_200_OK)
        else:
            return Response({'error': 'Invalid action'}, status=status.HTTP_400_BAD_REQUEST)


class SuperAdminStatsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not request.user.is_staff and not request.user.phone == '9999999999':
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)

        # 1. Total Revenue (sum of all completed/paid tokens)
        total_revenue = Token.objects.filter(is_paid=True).aggregate(Sum('total'))['total__sum'] or 0

        # 2. Active Shops
        active_shops = User.objects.filter(account_status='approved').count()
        trial_shops = User.objects.filter(account_status='trial').count()

        # 3. Weekly Data (Last 7 days revenue)
        today = timezone.localdate()
        weekly_data = []
        week_labels = []
        for i in range(6, -1, -1):
            day = today - timedelta(days=i)
            day_sum = Token.objects.filter(date=day, is_paid=True).aggregate(Sum('total'))['total__sum'] or 0
            weekly_data.append(float(day_sum))
            week_labels.append(day.strftime('%a'))

        # 4. Recent Transactions (Top 5 latest tokens)
        recent_tokens = Token.objects.all().order_by('-created_at')[:5]
        transactions = []
        for t in recent_tokens:
            shop_name = t.shop.name if t.shop else "Unknown Shop"
            minutes_ago = int((timezone.now() - t.created_at).total_seconds() / 60)
            time_str = f"{minutes_ago} mins ago" if minutes_ago < 60 else f"{minutes_ago // 60} hrs ago"
            
            transactions.append({
                'title': f'Token #{t.token_number} - {shop_name}',
                'meta': f'{t.bill_number} • {time_str}',
                'amount': f'+₹{t.total}',
                'status': 'completed' if t.is_paid else 'pending'
            })

        return Response({
            'total_revenue': float(total_revenue),
            'active_shops': active_shops,
            'trial_shops': trial_shops,
            'weekly_data': weekly_data,
            'week_labels': week_labels,
            'transactions': transactions
        }, status=status.HTTP_200_OK)


class SuperAdminLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get('username')
        password = request.data.get('password')

        if username == 'admin' and password == 'admin':
            # Get or create the '9999999999' super admin account
            user, created = User.objects.get_or_create(
                phone='9999999999',
                defaults={
                    'name': 'Super Admin',
                    'is_staff': True,
                    'is_superuser': True,
                    'account_status': 'approved'
                }
            )
            
            # Ensure it always has privileges
            if not user.is_staff or not user.is_superuser:
                user.is_staff = True
                user.is_superuser = True
                user.save()
            
            refresh = RefreshToken.for_user(user)

            return Response({
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'user': UserSerializer(user).data,
            }, status=status.HTTP_200_OK)
            
        return Response({'error': 'Invalid admin credentials'}, status=status.HTTP_401_UNAUTHORIZED)

class SuperAdminUsersView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not request.user.is_staff and not request.user.phone == '9999999999':
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
        
        users = User.objects.all().order_by('-created_at')
        return Response(UserSerializer(users, many=True).data, status=status.HTTP_200_OK)


class SuperAdminUpdatePermissionsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, user_id):
        if not request.user.is_staff and not request.user.phone == '9999999999':
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
            
        permissions = request.data.get('permissions', {})
        
        try:
            user = User.objects.get(id=user_id)
            user.permissions = permissions
            user.save()
            return Response({'message': 'Permissions updated successfully'}, status=status.HTTP_200_OK)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)


class SuperAdminDeleteUserView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, user_id):
        if not request.user.is_staff and not request.user.phone == '9999999999':
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
            
        try:
            user = User.objects.get(id=user_id)
            user.delete() # This will cascade delete associated Shop, Bills, etc.
            return Response({'message': 'User and associated data deleted successfully'}, status=status.HTTP_200_OK)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class SuperAdminSubscriptionPlanListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    queryset = SubscriptionPlan.objects.all()
    serializer_class = SubscriptionPlanSerializer

    def check_permissions(self, request):
        super().check_permissions(request)
        if not request.user.is_superuser and request.user.phone != '9999999999':
            self.permission_denied(request, message="Only Super Admins can manage plans.")


class SuperAdminSubscriptionPlanDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    queryset = SubscriptionPlan.objects.all()
    serializer_class = SubscriptionPlanSerializer

    def check_permissions(self, request):
        super().check_permissions(request)
        if not request.user.is_superuser and request.user.phone != '9999999999':
            self.permission_denied(request, message="Only Super Admins can manage plans.")


# ==============================================================================
# DEVELOPER MODE BYPASS APIS
# IMPORTANT: These endpoints bypass authentication and OTP. Remove in production!
# ==============================================================================

class DevUsersView(APIView):
    permission_classes = [AllowAny]
    
    def get(self, request):
        # Fetch all active users, super users first, then by creation date
        users = User.objects.filter(account_status__in=['approved', 'trial', 'pending']).order_by('-is_superuser', '-id')
        data = []
        for u in users:
            data.append({
                'id': u.id,
                'name': u.name or u.shop_name or u.phone,
                'phone': u.phone,
                'shop_name': u.shop_name,
                'is_superuser': u.is_superuser,
                'account_status': u.account_status,
            })
        return Response(data, status=status.HTTP_200_OK)


class DevLoginView(APIView):
    permission_classes = [AllowAny]
    
    def post(self, request):
        phone = request.data.get('phone')
        if not phone:
            return Response({'error': 'Phone number required'}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            user = User.objects.get(phone=phone)
            refresh = RefreshToken.for_user(user)
            
            # Additional response parameters matching regular VerifyOTP behavior
            user_data = UserSerializer(user).data
            return Response({
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'user': user_data,
                'is_staff': user.is_staff,
                'is_superuser': user.is_superuser,
                'message': 'Developer login successful'
            }, status=status.HTTP_200_OK)
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

class PublicSubscriptionPlanListView(generics.ListAPIView):
    permission_classes = [AllowAny]  # Plans must be public for registration & selection flow
    serializer_class = SubscriptionPlanSerializer
    
    def get_queryset(self):
        active_plans = SubscriptionPlan.objects.filter(is_active=True).order_by('display_order', 'id')
        if active_plans.exists():
            return active_plans
        return SubscriptionPlan.objects.all().order_by('display_order', 'id')

class SystemSettingsView(APIView):
    permission_classes = [AllowAny]
    
    def get(self, request):
        from .models import SystemSettings
        from .serializers import SystemSettingsSerializer
        settings = SystemSettings.get_settings()
        serializer = SystemSettingsSerializer(settings, context={'request': request})
        return Response(serializer.data)

    def post(self, request):
        from .models import SystemSettings
        from .serializers import SystemSettingsSerializer
        settings = SystemSettings.get_settings()
        
        upi_id = request.data.get('payment_upi_id')
        if upi_id is not None:
            settings.payment_upi_id = upi_id
            
        if 'payment_qr_code' in request.FILES:
            settings.payment_qr_code = request.FILES['payment_qr_code']
        elif 'payment_qr_code' in request.data and request.data['payment_qr_code']:
            qr_val = request.data['payment_qr_code']
            if isinstance(qr_val, str) and qr_val.startswith('data:image'):
                import base64
                from django.core.files.base import ContentFile
                format, imgstr = qr_val.split(';base64,')
                ext = format.split('/')[-1]
                settings.payment_qr_code = ContentFile(base64.b64decode(imgstr), name=f'payment_qr.{ext}')
            elif isinstance(qr_val, str) and not qr_val.startswith('http'):
                import base64
                from django.core.files.base import ContentFile
                try:
                    decoded = base64.b64decode(qr_val)
                    settings.payment_qr_code = ContentFile(decoded, name='payment_qr.png')
                except Exception:
                    pass

        settings.save()
        serializer = SystemSettingsSerializer(settings, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

class SubmitSubscriptionPaymentView(APIView):
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        from .models import SubscriptionPlan, SubscriptionPayment
        plan_id = request.data.get('plan_id')
        transaction_id = request.data.get('transaction_id')
        billing_cycle = request.data.get('billing_cycle', 'monthly')
        
        if not plan_id or not transaction_id:
            return Response({'error': 'plan_id and transaction_id are required'}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            plan = SubscriptionPlan.objects.get(id=plan_id, is_active=True)
        except SubscriptionPlan.DoesNotExist:
            return Response({'error': 'Invalid plan'}, status=status.HTTP_404_NOT_FOUND)
            
        amount = plan.price_monthly if billing_cycle == 'monthly' else plan.price_yearly
            
        payment = SubscriptionPayment.objects.create(
            user=request.user,
            plan=plan,
            billing_cycle=billing_cycle,
            transaction_id=transaction_id,
            amount_paid=amount,
            status='pending'
        )
        
        # Auto sync plan features to user permissions
        request.user.approved_plan = plan.name
        perms = request.user.permissions or {}
        if plan.features:
            for k, v in plan.features.items():
                perms[k] = v
        request.user.permissions = perms
        request.user.save()

        from .serializers import SubscriptionPaymentSerializer
        return Response(SubscriptionPaymentSerializer(payment).data, status=status.HTTP_201_CREATED)


class SuperAdminPaymentsView(APIView):
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        if not request.user.is_staff and not request.user.phone == '9999999999':
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
            
        from .models import SubscriptionPayment
        payments = SubscriptionPayment.objects.all().select_related('user', 'plan').order_by('-created_at')
        data = []
        for p in payments:
            data.append({
                'id': p.id,
                'user_id': p.user.id,
                'user_name': p.user.name or p.user.shop_name or p.user.phone,
                'user_phone': p.user.phone,
                'shop_name': p.user.shop_name or '',
                'plan_name': p.plan.name if p.plan else p.user.approved_plan,
                'billing_cycle': p.billing_cycle,
                'amount_paid': float(p.amount_paid),
                'transaction_id': p.transaction_id,
                'status': p.status,
                'created_at': p.created_at.strftime('%Y-%m-%d %H:%M:%S') if p.created_at else '',
            })
        return Response(data, status=status.HTTP_200_OK)

