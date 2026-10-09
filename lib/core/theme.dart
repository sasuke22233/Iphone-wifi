import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Фирменные цвета Aura VPN.
class AuraColors {
  AuraColors._();

  static const Color bgTop = Color(0xFF0A0E1A);
  static const Color bgBottom = Color(0xFF101627);
  static const Color surface = Color(0xFF161D31);
  static const Color surfaceLight = Color(0xFF1D2540);

  static const Color accent = Color(0xFF7C5CFF);
  static const Color accent2 = Color(0xFF00C2FF);
  static const Color success = Color(0xFF2CE5A6);
  static const Color warning = Color(0xFFFFB454);
  static const Color danger = Color(0xFFFF5C7A);

  static const Color textPrimary = Color(0xFFF2F4FF);
  static const Color textSecondary = Color(0xFF9AA3C0);
  static const Color textFaint = Color(0xFF5D6684);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C5CFF), Color(0xFF4E7CFF), Color(0xFF00C2FF)],
  );

  static const LinearGradient connectedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2CE5A6), Color(0xFF00B8D9)],
  );

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
    stops: [0.0, 1.0],
  );

  static const RadialGradient glowGradient = RadialGradient(
    center: Alignment(-0.8, -0.9),
    radius: 1.4,
    colors: [Color(0x337C5CFF), Color(0x00101627)],
    stops: [0.0, 1.0],
  );
}

/// Тёмная тема приложения.
class AuraTheme {
  AuraTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: null,
      colorScheme: const ColorScheme.dark(
        primary: AuraColors.accent,
        secondary: AuraColors.accent2,
        surface: AuraColors.surface,
        error: AuraColors.danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AuraColors.textPrimary,
      ),
      scaffoldBackgroundColor: AuraColors.bgBottom,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: AuraColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: AuraColors.textPrimary),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AuraColors.textPrimary,
        displayColor: AuraColors.textPrimary,
      ).copyWith(
        headlineLarge: const TextStyle(
          color: AuraColors.textPrimary,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        headlineMedium: const TextStyle(
          color: AuraColors.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleLarge: const TextStyle(
          color: AuraColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: const TextStyle(
          color: AuraColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(
          color: AuraColors.textPrimary,
          fontSize: 15,
          height: 1.35,
        ),
        bodyMedium: const TextStyle(
          color: AuraColors.textSecondary,
          fontSize: 13.5,
          height: 1.35,
        ),
        labelLarge: const TextStyle(
          color: AuraColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: const TextStyle(
          color: AuraColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.07),
        thickness: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AuraColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AuraColors.surfaceLight,
        contentTextStyle: const TextStyle(color: AuraColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.white
              : AuraColors.textFaint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AuraColors.accent
              : Colors.white.withOpacity(0.12),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        hintStyle: const TextStyle(color: AuraColors.textFaint),
        labelStyle: const TextStyle(color: AuraColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: AuraColors.accent2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AuraColors.accent2, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AuraColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AuraColors.textPrimary,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: Colors.white.withOpacity(0.16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AuraColors.accent.withOpacity(0.22)
                : Colors.white.withOpacity(0.04),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AuraColors.accent2
                : AuraColors.textSecondary,
          ),
          side: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AuraColors.textSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
