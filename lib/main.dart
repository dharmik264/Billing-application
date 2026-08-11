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
    final startTime = DateTime.now();
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

      // Ensure total splash screen display duration is fast & smooth (~1.2s)
      final elapsed = DateTime.now().difference(startTime);
      const minSplashDuration = Duration(milliseconds: 1200);
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
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
      final elapsed = DateTime.now().difference(startTime);
      const minSplashDuration = Duration(seconds: 5);
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
      }
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0F172A), // Dark Slate
              Color(0xFF1E1B4B), // Deep Indigo
              Color(0xFF312E81), // Rich Indigo Accent
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Animated Glowing Icon Container
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                      blurRadius: 45,
                      spreadRadius: 8,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.95, end: 1.05, duration: 2000.ms, curve: Curves.easeInOut)
                  .then()
                  .animate()
                  .fadeIn(duration: 700.ms)
                  .scaleXY(begin: 0.4, end: 1.0, curve: Curves.elasticOut, duration: 900.ms),

              const SizedBox(height: 32),

              // Animated App Title
              Text(
                'BillEase POS',
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              )
                  .animate()
                  .fadeIn(delay: 350.ms, duration: 600.ms)
                  .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic)
                  .shimmer(delay: 1200.ms, duration: 1800.ms, color: Colors.white38),

              const SizedBox(height: 10),

              // Tagline
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    Text(
                      'Smart · Fast · Secure Billing',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 550.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),

              const Spacer(flex: 3),

              // Smooth Loading Indicator & Version Info
              Column(
                children: [
                  SizedBox(
                    width: 150,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(
                        backgroundColor: Color(0xFF334155),
                        color: Color(0xFF38BDF8),
                        minHeight: 4,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 500.ms),

                  const SizedBox(height: 18),

                  Text(
                    'VERSION 1.0.5',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                      letterSpacing: 1.5,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 950.ms, duration: 500.ms),
                ],
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
