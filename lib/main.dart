import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/password_login_screen.dart';
import 'screens/shop_setup_screen.dart';
import 'screens/main_screen.dart';
import 'screens/super_admin_main_screen.dart';
import 'services/restaurant_api.dart';
import 'utils/bill_counter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom Error Handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Global Error Caught: ${details.exception}');
  };

  runApp(const BillingApplication());
}

class BillingApplication extends StatelessWidget {
  const BillingApplication({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Billing Application',
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // Vibrant Indigo
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF06B6D4), // Cyan for accents
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final bool isSetupComplete = prefs.getBool('isSetupComplete') ?? false;

      // Initialize API tokens securely
      await RestaurantApi.instance.loadTokens();

      // Verify session persistence
      if (isLoggedIn && !RestaurantApi.instance.hasValidToken) {
        isLoggedIn = false;
        await prefs.setBool('isLoggedIn', false);
      }

      int loginTimestamp = prefs.getInt('loginTimestamp') ?? 0;
      if (isLoggedIn && loginTimestamp > 0) {
        final loginDate = DateTime.fromMillisecondsSinceEpoch(loginTimestamp);
        if (DateTime.now().difference(loginDate).inDays >= 15) {
          isLoggedIn = false;
          await prefs.setBool('isLoggedIn', false);
          // clear tokens
        }
      }

      // Check Trial Expiry
      if (isLoggedIn) {
        final status = prefs.getString('account_status');
        if (status == 'trial') {
          final trialEndStr = prefs.getString('trial_end');
          if (trialEndStr != null && trialEndStr.isNotEmpty) {
            final trialEnd = DateTime.tryParse(trialEndStr);
            if (trialEnd != null && DateTime.now().isAfter(trialEnd)) {
              isLoggedIn = false;
              await prefs.setBool('isLoggedIn', false);
              // In a real app, clear token from secure storage here
              debugPrint('Trial expired. Logging out.');
            }
          }
        }
      }

      if (!mounted) return;

      // Super Admin auto-login routing
      final loginPhone = prefs.getString('loginPhone') ?? '';
      if (isLoggedIn && loginPhone == '9999999999') {
        _navigateTo(const SuperAdminMainScreen());
        return;
      }

      // Routing Management Logic
      if (!isLoggedIn) {
        _navigateTo(const PasswordLoginScreen());
      } else if (!isSetupComplete) {
        _navigateTo(const ShopSetupScreen());
      } else {
        await BillCounter.initialize(); // Seed counters
        _navigateTo(const MainScreen());
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        _navigateTo(
            const PasswordLoginScreen()); // Fallback to login on critical failure
      }
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}
