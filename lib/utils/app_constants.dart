import 'package:flutter/material.dart';

/// App-wide color constants
class AppColors {
  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0F4FF), Color(0xFFFAF5FF)],
  );

  // Primary Colors
  static const Color primary = Color(0xFF2563EB); // Blue
  static const Color success = Color(0xFF16A34A); // Green
  static const Color error = Color(0xFFDC2626); // Red
  static const Color warning = Color(0xFFEA580C); // Orange

  // Neutral Colors
  static const Color dark = Color(0xFF1F2937);
  static const Color darkGrey = Color(0xFF555555);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFBBBBBB);
  static const Color border = Color(0xFFDDDDDD);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color white = Colors.white;
  static const Color background = Color(0xFFFFF7ED); // Light orange background

  // Backgrounds
  static const Color errorBackground = Color(0xFFFEF2F2); // Light red
  static const Color errorBorder = Color(0xFFFECACA); // Light red border
  static const Color errorText = Color(0xFF991B1B); // Dark red

  // Status indicator
  static const Color online = Color(0xFF16A34A); // Green
}

/// App-wide text style constants
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.dark,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 15,
    color: AppColors.dark,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.grey,
  );

  static const TextStyle smallCaption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.grey,
    letterSpacing: 0.5,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14,
    color: AppColors.darkGrey,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 13,
    color: AppColors.grey,
  );

  static const TextStyle errorText = TextStyle(
    fontSize: 12,
    color: AppColors.errorText,
  );

  static const TextStyle resendLink = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
  );
}

/// App-wide spacing constants
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

/// App-wide border radius constants
class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 28;
  static const double round = 50;
}

/// App-wide size constants
class AppSizes {
  // Button sizes
  static const double buttonHeight = 48;
  static const double buttonHeightSmall = 40;

  // Icon sizes
  static const double iconSmall = 14;
  static const double iconDefault = 17;
  static const double iconLarge = 34;

  // Card sizes
  static const double cardWidth = 360;
  static const double cardMinHeight = 620;

  // Input field sizes
  static const double otpFieldSize = 56;
  static const double headerIconSize = 70;
  static const double backButtonSize = 34;
}
