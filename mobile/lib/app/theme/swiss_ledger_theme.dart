import 'package:flutter/material.dart';

class PhosphorIconsRegular {
  const PhosphorIconsRegular._();

  static const IconData forkKnife = Icons.restaurant_outlined;
  static const IconData carSimple = Icons.directions_car_outlined;
  static const IconData houseLine = Icons.home_outlined;
  static const IconData lightning = Icons.bolt_outlined;
  static const IconData calendarCheck = Icons.event_available_outlined;
  static const IconData firstAidKit = Icons.medical_services_outlined;
  static const IconData filmSlate = Icons.movie_outlined;
  static const IconData shoppingBag = Icons.shopping_bag_outlined;
  static const IconData wallet = Icons.account_balance_wallet_outlined;
  static const IconData coins = Icons.paid_outlined;
  static const IconData briefcase = Icons.work_outline;
  static const IconData arrowDownLeft = Icons.south_west_outlined;
  static const IconData receipt = Icons.receipt_long_outlined;
  static const IconData bookBookmark = Icons.menu_book_outlined;
  static const IconData userCircle = Icons.account_circle_outlined;
  static const IconData slidersHorizontal = Icons.tune_outlined;
  static const IconData backspace = Icons.backspace_outlined;
  static const IconData magnifyingGlass = Icons.search_outlined;
  static const IconData bookOpenText = Icons.menu_book_outlined;
  static const IconData scales = Icons.balance_outlined;
  static const IconData plus = Icons.add;
  static const IconData bookmarkSimple = Icons.bookmark_border_outlined;
  static const IconData filePdf = Icons.picture_as_pdf_outlined;
  static const IconData downloadSimple = Icons.file_download_outlined;
  static const IconData signOut = Icons.logout_outlined;
  static const IconData warningCircle = Icons.error_outline;
  static const IconData checkCircle = Icons.check_circle_outline;
}

class SwissLedgerColors {
  const SwissLedgerColors._();

  static const Color bgPrimary = Color(0xFFFAF9F6);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F0EC);
  static const Color borderHairline = Color(0xFFE5E4DF);
  static const Color textPrimary = Color(0xFF141413);
  static const Color textMuted = Color(0xFF6E6D68);
  static const Color accentTeal = Color(0xFF0F766E);
  static const Color accentTealSubtle = Color(0xFFE6F4F1);
  static const Color warningAmber = Color(0xFFB45309);
  static const Color warningSubtle = Color(0xFFFEF3C7);
  static const Color dangerRed = Color(0xFFB91C1C);
  static const Color dangerSubtle = Color(0xFFFEE2E2);

  static const Color darkBgPrimary = Color(0xFF121316);
  static const Color darkSurfaceElevated = Color(0xFF1A1C20);
  static const Color darkSurfaceSubtle = Color(0xFF23262B);
  static const Color darkBorderHairline = Color(0xFF2C3036);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextMuted = Color(0xFF8E95A2);
  static const Color darkAccentTeal = Color(0xFF0D9488);
}

class SwissLedgerTypography {
  const SwissLedgerTypography._();

  static TextStyle monoTabular({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color color = SwissLedgerColors.textPrimary,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFamilyFallback: const ['Consolas', 'monospace'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? -0.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static TextStyle sans({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = SwissLedgerColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontFamilyFallback: const ['Segoe UI', 'Roboto', 'sans-serif'],
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

class CategoryIconMapper {
  const CategoryIconMapper._();

  static IconData fromKey(String iconKey) {
    final normalized = iconKey.trim().toLowerCase().replaceAll('-', '_');
    switch (normalized) {
      case 'fork_knife':
        return PhosphorIconsRegular.forkKnife;
      case 'car_simple':
      case 'gas_pump':
        return PhosphorIconsRegular.carSimple;
      case 'house_line':
        return PhosphorIconsRegular.houseLine;
      case 'lightning':
        return PhosphorIconsRegular.lightning;
      case 'calendar_check':
        return PhosphorIconsRegular.calendarCheck;
      case 'first_aid_kit':
        return PhosphorIconsRegular.firstAidKit;
      case 'film_slate':
        return PhosphorIconsRegular.filmSlate;
      case 'shopping_bag':
        return PhosphorIconsRegular.shoppingBag;
      case 'wallet':
        return PhosphorIconsRegular.wallet;
      case 'coins':
      case 'hand_coins':
        return PhosphorIconsRegular.coins;
      case 'briefcase':
        return PhosphorIconsRegular.briefcase;
      case 'arrow_down_left':
      case 'plus_circle':
        return PhosphorIconsRegular.arrowDownLeft;
      default:
        return PhosphorIconsRegular.receipt;
    }
  }
}

class SwissLedgerTheme {
  const SwissLedgerTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: SwissLedgerColors.bgPrimary,
      colorScheme: const ColorScheme.light(
        primary: SwissLedgerColors.accentTeal,
        onPrimary: Colors.white,
        surface: SwissLedgerColors.surfaceElevated,
        onSurface: SwissLedgerColors.textPrimary,
        error: SwissLedgerColors.dangerRed,
      ),
      dividerColor: SwissLedgerColors.borderHairline,
      cardTheme: CardThemeData(
        color: SwissLedgerColors.surfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: SwissLedgerColors.borderHairline,
            width: 1,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: SwissLedgerColors.surfaceElevated,
        foregroundColor: SwissLedgerColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SwissLedgerColors.darkBgPrimary,
      colorScheme: const ColorScheme.dark(
        primary: SwissLedgerColors.darkAccentTeal,
        onPrimary: Colors.white,
        surface: SwissLedgerColors.darkSurfaceElevated,
        onSurface: SwissLedgerColors.darkTextPrimary,
        error: SwissLedgerColors.dangerRed,
      ),
      dividerColor: SwissLedgerColors.darkBorderHairline,
      cardTheme: CardThemeData(
        color: SwissLedgerColors.darkSurfaceElevated,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: SwissLedgerColors.darkBorderHairline,
            width: 1,
          ),
        ),
      ),
    );
  }
}
