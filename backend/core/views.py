from rest_framework import status, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework_simplejwt.tokens import RefreshToken
from django.utils import timezone

from .models import User, OTP, AppSettings
from .serializers import SendOTPSerializer, VerifyOTPSerializer, UserSerializer, AppSettingsSerializer


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

        user, created = User.objects.get_or_create(phone=phone)
        
        # Grant admin panel access and set password as mobile number
        user.is_staff = True
        user.set_password(phone)
        user.save()
        
        refresh = RefreshToken.for_user(user)

        return Response({
            'access':  str(refresh.access_token),
            'refresh': str(refresh),
            'user':    UserSerializer(user).data,
            'is_new_user': created,
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
