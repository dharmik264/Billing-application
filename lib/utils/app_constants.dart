import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stitch Minimal Business Design System Colors
class StitchColors {
  // Brand & Primary Palette (Monochromatic Slate & Deep Indigo accent)
  static const Color primary = Color(0xFF4F46E5); // Deep Indigo
  static const Color primaryHover = Color(0xFF4338CA);
  static const Color primaryDark = Color(0xFF0F172A); // Dark Slate header/sidebar
  static const Color secondary = Color(0xFF0284C7); // Sky Blue accent

  // Neutral Surfaces (Flat, crisp Minimal Business)
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceHover = Color(0xFFF8FAFC);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900 (High contrast)
  static const Color textSecondary = Color(0xFF334155); // Slate 700 (Body)
  static const Color textMuted = Color(0xFF64748B); // Slate 500 (Captions/Subtitles)
  static const Color textDisabled = Color(0xFF94A3B8); // Slate 400

  // Crisp 1px Borders & Dividers
  static const Color border = Color(0xFFE2E8F0); // Slate 200 (Default 1px border)
  static const Color borderSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color borderFocus = Color(0xFF4F46E5); // Indigo 600

  // Functional Status Badges & Indicators
  static const Color successBg = Color(0xFFECFDF5);
  static const Color successText = Color(0xFF047857);
  static const Color successBorder = Color(0xFFA7F3D0);

  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningText = Color(0xFFB45309);
  static const Color warningBorder = Color(0xFFFDE68A);

  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color dangerText = Color(0xFFB91C1C);
  static const Color dangerBorder = Color(0xFFFECACA);

  static const Color infoBg = Color(0xFFEFF6FF);
  static const Color infoText = Color(0xFF1D4ED8);
  static const Color infoBorder = Color(0xFFBFDBFE);
}

/// App-wide color constants (Compatible with Stitch System)
class AppColors {
  // Gradients (Subtle flat fallback)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
  );

  // Primary Colors
  static const Color primary = StitchColors.primary;
  static const Color success = StitchColors.successText;
  static const Color error = StitchColors.dangerText;
  static const Color warning = StitchColors.warningText;

  // Neutral Colors
  static const Color dark = StitchColors.textPrimary;
  static const Color darkGrey = StitchColors.textSecondary;
  static const Color grey = StitchColors.textMuted;
  static const Color lightGrey = StitchColors.textDisabled;
  static const Color border = StitchColors.border;
  static const Color divider = StitchColors.borderSubtle;
  static const Color white = Colors.white;
  static const Color background = StitchColors.background;

  // Backgrounds
  static const Color errorBackground = StitchColors.dangerBg;
  static const Color errorBorder = StitchColors.dangerBorder;
  static const Color errorText = StitchColors.dangerText;

  // Status indicator
  static const Color online = StitchColors.successText;

  // Modern UI Colors (Tailwind-inspired)
  static const Color slate900 = StitchColors.textPrimary;
  static const Color slate500 = StitchColors.textMuted;
  static const Color slate400 = StitchColors.textDisabled;
  static const Color slate200 = StitchColors.border;
  static const Color slate100 = StitchColors.surfaceSubtle;
  static const Color slate50 = StitchColors.background;

  static const Color indigo600 = StitchColors.primary;
  static const Color emerald500 = Color(0xFF10B981);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color red500 = Color(0xFFEF4444);
}

/// Stitch Minimal Business Typography Scale
class StitchTypography {
  static TextStyle title({Color color = StitchColors.textPrimary, double size = 18}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.25,
    );
  }

  static TextStyle header({Color color = StitchColors.textPrimary, double size = 15}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle body({Color color = StitchColors.textSecondary, double size = 13, FontWeight weight = FontWeight.w400}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.4,
    );
  }

  static TextStyle caption({Color color = StitchColors.textMuted, double size = 11}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color,
      height: 1.3,
    );
  }

  static TextStyle monospace({Color color = StitchColors.textPrimary, double size = 13, FontWeight weight = FontWeight.w600}) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}

/// App-wide text style constants
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: StitchColors.textPrimary,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 14,
    color: StitchColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: StitchColors.textMuted,
  );

  static const TextStyle smallCaption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: StitchColors.textMuted,
    letterSpacing: 0.5,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: StitchColors.textSecondary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 13,
    color: StitchColors.textMuted,
  );

  static const TextStyle errorText = TextStyle(
    fontSize: 12,
    color: StitchColors.dangerText,
  );

  static const TextStyle resendLink = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: StitchColors.primary,
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

/// Stitch Minimal Business Border Radius (Crisp & Compact)
class AppRadius {
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double round = 50;

  static BorderRadius radiusSm = BorderRadius.circular(sm);
  static BorderRadius radiusMd = BorderRadius.circular(md);
  static BorderRadius radiusLg = BorderRadius.circular(lg);
}

/// Stitch Minimal Business Sizes
class AppSizes {
  static const double buttonHeight = 40;
  static const double buttonHeightSmall = 34;

  static const double iconSmall = 14;
  static const double iconDefault = 18;
  static const double iconLarge = 24;

  static const double cardWidth = 360;
  static const double cardMinHeight = 580;

  static const double inputHeight = 40;
  static const double otpFieldSize = 52;
  static const double headerIconSize = 60;
  static const double backButtonSize = 32;
}

/// Stitch Minimal Business Card & Surface BoxDecorations
class StitchDecorations {
  static BoxDecoration card({
    Color backgroundColor = StitchColors.surface,
    Color borderColor = StitchColors.border,
    double radius = AppRadius.md,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.0),
    );
  }

  static BoxDecoration cardFocused({
    Color backgroundColor = StitchColors.surface,
    double radius = AppRadius.md,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: StitchColors.primary, width: 1.5),
    );
  }

  static BoxDecoration badge({
    required Color backgroundColor,
    required Color borderColor,
    double radius = AppRadius.sm,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.0),
    );
  }
}

