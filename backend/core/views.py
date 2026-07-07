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
        user.set_unusable_password()
        
        Shop.objects.create(owner=user, name=shop_name, email=email, phone=phone)
        
        code = OTP.generate_code()
        OTP.objects.create(phone=phone, code=code)
        
        print(f"DEVELOPMENT OTP FOR {phone}: {code}")
        print("="*45 + "\n")
        
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

        # Invalidate old OTPs
        OTP.objects.filter(phone=phone, is_used=False).update(is_used=True)

        code = OTP.generate_code()
        OTP.objects.create(phone=phone, code=code)

        # TODO: Integrate real SMS gateway
        print(f"DEVELOPMENT OTP FOR {phone}: {code}")
        print("="*45 + "\n")

        # TODO: Integrate SMS gateway (Twilio / MSG91)
        # For dev, return OTP in response
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
            user.save()
            return Response({'message': 'Shop approved successfully'}, status=status.HTTP_200_OK)
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
