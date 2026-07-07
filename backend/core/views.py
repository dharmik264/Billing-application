from rest_framework import status, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken
from django.utils import timezone
from datetime import timedelta

from .models import User, OTP, AppSettings
from .serializers import SendOTPSerializer, VerifyOTPSerializer, UserSerializer, AppSettingsSerializer, RegisterSerializer
from shop.models import Shop


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
        if not request.user.is_superuser:
            return Response({'error': 'Unauthorized'}, status=status.HTTP_403_FORBIDDEN)
        
        users = User.objects.filter(account_status__in=['pending', 'trial']).order_by('-created_at')
        return Response(UserSerializer(users, many=True).data, status=status.HTTP_200_OK)


class ShopRequestActionView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, user_id):
        if not request.user.is_superuser:
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
