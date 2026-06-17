# Setup & Getting Started Guide

## Quick Start

### Prerequisites
- Flutter SDK installed (Flutter 3.0+)
- Dart 3.0+
- Android Studio/Xcode (for emulator) or physical device

### Installation Steps

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Run the App**
   ```bash
   flutter run
   ```

3. **Build for Production**
   ```bash
   # Android
   flutter build apk
   flutter build appbundle
   
   # iOS
   flutter build ios
   flutter build ipa
   ```

---

## Features Overview

### 📱 Mobile Number Input
- Country code selector (+91)
- Automatic formatting to 10 digits
- Input validation before OTP send

**Test with any 10-digit number:**
- Example: `9845012345`

### 📲 OTP Entry
- 4 individual digit input fields
- **Auto-focus to next field** after digit entry
- **Backspace navigation** to previous field
- Numeric keyboard only

### ✅ OTP Verification
- **Correct OTP for Testing:** `4242`
- Attempt tracking (max 2 attempts)
- Clear error messages with attempt count
- Automatic form reset after max attempts

### 🔄 Resend OTP
- 30-second cooldown timer
- Button disables during cooldown
- Timer display updates every second
- Clears previous OTP on resend

---

## Customization Guide

### Colors
Edit `lib/utils/app_constants.dart`:
```dart
static const Color primary = Color(0xFF2563EB); // Change primary blue
static const Color success = Color(0xFF16A34A); // Change green
```

### Text Styles
Modify existing styles in `AppTextStyles` class:
```dart
static const TextStyle heading1 = TextStyle(
  fontSize: 20,           // Adjust size
  fontWeight: FontWeight.w500,
  color: AppColors.dark,
);
```

### Spacing & Sizes
Update `AppSpacing` and `AppSizes`:
```dart
static const double md = 12;  // Adjust base spacing
static const double buttonHeight = 48;  // Adjust button height
```

### UI Layout
Edit `lib/screens/otp_login_screen.dart`:
- Change card width/height
- Modify gradient colors
- Adjust padding/margins
- Update border radius values

---

## API Integration

### Sending OTP
Replace the `_sendOTP()` method:
```dart
void _sendOTP() async {
  try {
    final response = await http.post(
      Uri.parse('https://your-api.com/send-otp'),
      body: {'phone': _mobileController.text},
    );
    if (response.statusCode == 200) {
      setState(() => _showOTPSection = true);
    }
  } catch (e) {
    // Handle error
  }
}
```

### Verifying OTP
Replace the `_verifyOTP()` method:
```dart
void _verifyOTP() async {
  try {
    final enteredOTP = _otpControllers.map((c) => c.text).join();
    final response = await http.post(
      Uri.parse('https://your-api.com/verify-otp'),
      body: {
        'phone': _mobileController.text,
        'otp': enteredOTP,
      },
    );
    // Handle response
  } catch (e) {
    // Handle error
  }
}
```

---

## Advanced Features

### Custom OTP Length
Change from 4 digits to any length:
```dart
// In initState()
_otpControllers = List.generate(6, (_) => TextEditingController()); // 6 digits
_otpFocusNodes = List.generate(6, (_) => FocusNode());

// In build()
// Add more _buildOTPField() widgets as needed
```

### Add Password Strength Indicator
Create a new widget and add it before the button.

### Add Multi-language Support
Use `intl` package and create translation files.

---

## Testing Scenarios

| Scenario | Phone | OTP | Expected Result |
|----------|-------|-----|-----------------|
| Valid OTP | Any 10-digit | 4242 | Login successful |
| Wrong OTP (1st) | Any 10-digit | Any except 4242 | Error shown, 2 attempts remaining |
| Wrong OTP (2nd) | Any 10-digit | Any except 4242 | Form resets, max attempts reached |
| Empty OTP | Any 10-digit | (empty) | Incomplete OTP error |
| Resend OTP | Any 10-digit | Tap Resend | 30-second cooldown starts |

---

## Troubleshooting

### Keyboard not showing
- Ensure FocusingNode focus management is working
- Check that `autofocus: true` is not conflicting with custom focus logic

### Timer not updating
- Verify the `Future.doWhile()` loop in `_resendOTP()` is executing
- Check that `setState()` is being called inside the loop

### Back button not working
- Ensure `Navigator` context is available
- Comment it out for back navigation testing

### Colors not matching HTML
- Verify hex color codes in `AppColors` class
- Check gradient angle alignment in background

---

## File Structure Explanation

```
billing_application/
├── android/              # Android native code
├── ios/                  # iOS native code
├── lib/
│   ├── main.dart        # App entry point & theme setup
│   ├── screens/
│   │   └── otp_login_screen.dart  # Main OTP UI screen
│   └── utils/
│       └── app_constants.dart     # Colors, text styles, sizes
├── pubspec.yaml         # Dependencies & project config
├── analysis_options.yaml # Lint rules
├── README.md            # Feature overview
├── SETUP_GUIDE.md       # This file
└── .gitignore          # Git ignore rules
```

---

## Next Steps

1. **Run the app:** `flutter run`
2. **Test locally** with the OTP `4242`
3. **Connect to backend API** using the integration guide
4. **Customize colors/styles** using constants
5. **Add navigation** to success/home screen
6. **Deploy to production** using build commands

---

## Support

For issues or questions:
- Check Flutter documentation: https://flutter.dev/docs
- Visit Flutter community: https://flutter.dev/community
- Check Dart packages: https://pub.dev

Happy coding! 🚀
