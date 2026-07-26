import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
          seedColor: const Color(0xFF4F46E5),
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF06B6D4),
        ),
        // Global page transitions
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SlidePageTransition(),
            TargetPlatform.iOS: _SlidePageTransition(),
          },
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Global smooth slide+fade page transition
class _SlidePageTransition extends PageTransitionsBuilder {
  const _SlidePageTransition();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuint)),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
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

      // Verify setup status if locally false but user is logged in
      bool actualSetupComplete = isSetupComplete;
      if (isLoggedIn && !isSetupComplete && loginPhone != '9999999999') {
        try {
          final shop = await RestaurantApi.instance.fetchShop(forceRefresh: true);
          if (shop.paymentModesConfig != null && shop.paymentModesConfig!.isNotEmpty) {
            actualSetupComplete = true;
            await prefs.setBool('isSetupComplete', true);
          }
        } catch (_) {
          // If offline or fails, fallback to existing local state
        }
      }

      if (!mounted) return;

      // Routing Management Logic
      if (!isLoggedIn) {
        _navigateTo(const PasswordLoginScreen());
      } else if (!actualSetupComplete && loginPhone != '9999999999') {
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
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => screen,
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lock orientation during splash
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                      blurRadius: 32,
                      spreadRadius: 4,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.95, end: 1.05, duration: 1800.ms, curve: Curves.easeInOut)
                  .then()
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scaleXY(begin: 0.5, end: 1.0, curve: Curves.elasticOut, duration: 800.ms),
              const SizedBox(height: 28),
              // App Name
              Text(
                'BillEase POS',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 500.ms)
                  .slideY(begin: 0.3, end: 0, delay: 300.ms, curve: Curves.easeOut),
              const SizedBox(height: 8),
              Text(
                'Smart Billing · Fast Tokens · Easy Payments',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 500.ms),
              const SizedBox(height: 60),
              // Loading bar
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    backgroundColor: Color(0xFFE2E8F0),
                    color: Color(0xFF4F46E5),
                    minHeight: 4,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 700.ms),
            ],
          ),
        ),
      ),
    );
  }
}
