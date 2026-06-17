# OTP Login Screen - Flutter UI

A beautiful Flutter implementation of an OTP login screen matching the provided HTML design.

## Features

✅ **Mobile Number Input**
- Country code selector (+91)
- Phone number validation
- Input formatting

✅ **OTP Entry**
- 4-digit OTP input fields with auto-focus
- Numeric keyboard only
- Auto-focus to next field after digit entry
- Backspace navigation between fields

✅ **Full Frontend Functionality**
- Send OTP button with validation
- Resend OTP with 30-second countdown timer
- OTP verification with attempt tracking
- Error messages with remaining attempts display
- Form reset capability

✅ **UI/UX Design**
- Gradient background matching HTML design
- Responsive card-based layout
- Smooth transitions and interactions
- Professional styling with proper spacing
- Security information display
- Terms and Privacy links

## Installation

1. Open the project in VS Code or Android Studio
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to launch the app

## Project Structure

```
lib/
├── main.dart                 # App entry point
└── screens/
    └── otp_login_screen.dart # Main OTP login UI
```

## Features Demo

### For Testing OTP Verification:
- **Correct OTP**: 4242
- **Mobile Number**: Any 10-digit number (e.g., 9845012345)

### Interactive Features:
- Click the back button to reset and start over
- Enter mobile number and tap "Send OTP"
- Enter OTP digits with auto-focus
- Tap "Resend OTP" to reset with cooldown
- Wrong OTP shows error with remaining attempts
- After 2 failed attempts, form resets

## Customization

You can customize:
- Colors in the `decoration` properties
- OTP length by modifying the list generation (currently 4)
- Country code in the mobile input
- Validation rules in `_sendOTP()` and `_verifyOTP()`
- API integration points for real OTP backend

## Future Enhancements

- Integration with backend API for real OTP delivery
- Social login options (Google, Apple, etc.)
- Multi-language support
- Biometric authentication
- Custom font families
- Animation effects
