import 'package:flutter/material.dart';

/// HabitTech's design tokens. Light values follow the product palette:
/// primary blue #5B9BD5, light blue #DCEFFD, page #F4F9FD, border #C9E2F8,
/// text #1D3854, success #3EAD7B, warning #F0B45B, error #E66B6B.
///
/// Two deliberate accessibility adjustments:
///  * [primaryStrong] (a deeper blue) is used for filled buttons, links and
///    small icons so white text/graphics reach WCAG AA contrast; the original
///    #5B9BD5 stays as the accent for charts, progress and checkmarks.
///  * [textSecondary] is slightly darker than #71849A to reach 4.5:1 on white.
@immutable
class HabitColors extends ThemeExtension<HabitColors> {
  const HabitColors({
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.background,
    required this.card,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color background;
  final Color card;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color error;

  static const HabitColors light = HabitColors(
    primary: Color(0xFF5B9BD5),
    primaryStrong: Color(0xFF2F73B3),
    primarySoft: Color(0xFFDCEFFD),
    background: Color(0xFFF4F9FD),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFC9E2F8),
    text: Color(0xFF1D3854),
    textSecondary: Color(0xFF627589),
    success: Color(0xFF3EAD7B),
    warning: Color(0xFFF0B45B),
    error: Color(0xFFE66B6B),
  );

  static const HabitColors dark = HabitColors(
    primary: Color(0xFF6FAEE3),
    primaryStrong: Color(0xFF8CC1EE),
    primarySoft: Color(0xFF1E3A55),
    background: Color(0xFF0E1A28),
    card: Color(0xFF152536),
    border: Color(0xFF29445E),
    text: Color(0xFFE8F1FA),
    textSecondary: Color(0xFF9DB2C7),
    success: Color(0xFF55C294),
    warning: Color(0xFFF0B45B),
    error: Color(0xFFEE8585),
  );

  @override
  HabitColors copyWith({
    Color? primary,
    Color? primaryStrong,
    Color? primarySoft,
    Color? background,
    Color? card,
    Color? border,
    Color? text,
    Color? textSecondary,
    Color? success,
    Color? warning,
    Color? error,
  }) =>
      HabitColors(
        primary: primary ?? this.primary,
        primaryStrong: primaryStrong ?? this.primaryStrong,
        primarySoft: primarySoft ?? this.primarySoft,
        background: background ?? this.background,
        card: card ?? this.card,
        border: border ?? this.border,
        text: text ?? this.text,
        textSecondary: textSecondary ?? this.textSecondary,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
      );

  @override
  HabitColors lerp(ThemeExtension<HabitColors>? other, double t) {
    if (other is! HabitColors) return this;
    return HabitColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension HabitColorsContext on BuildContext {
  HabitColors get hc => Theme.of(this).extension<HabitColors>()!;
}

/// Destructive button background; dark enough for white text (AA).
const Color kDestructive = Color(0xFFB83A3A);

const double kCardRadius = 18;
const double kControlRadius = 14;

ThemeData buildTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final c = isLight ? HabitColors.light : HabitColors.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primaryStrong,
    onPrimary: isLight ? Colors.white : const Color(0xFF0B2036),
    primaryContainer: c.primarySoft,
    onPrimaryContainer: c.text,
    secondary: c.primaryStrong,
    onSecondary: isLight ? Colors.white : const Color(0xFF0B2036),
    secondaryContainer: c.primarySoft,
    onSecondaryContainer: c.text,
    error: isLight ? kDestructive : c.error,
    onError: isLight ? Colors.white : const Color(0xFF2A0A0A),
    surface: c.card,
    onSurface: c.text,
    outline: c.border,
    outlineVariant: c.border,
  );

  final base = ThemeData(brightness: brightness, useMaterial3: true);
  final textTheme = base.textTheme.apply(
    bodyColor: c.text,
    displayColor: c.text,
  );

  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kControlRadius),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[c],
    dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
        foregroundColor: c.primaryStrong,
        side: BorderSide(color: c.border, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
        foregroundColor: c.primaryStrong,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      indicatorColor: c.primarySoft,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.card,
      indicatorColor: c.primarySoft,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: TextStyle(color: c.card, fontSize: 14),
    ),
  );
}
