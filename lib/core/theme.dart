import 'package:flutter/material.dart';

/// ALL visual styling lives here as tokens (IMPLEMENTATION_PLAN §5). The real
/// HandySpeak design ships later; centralizing colors/spacing/radii makes the
/// reskin a find-and-replace rather than a rewrite.
///
/// Colors are approximate sRGB conversions of the prototype's OKLCH palette
/// (styles.css). Two variants: light + dark.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.divider,
    required this.dividerSoft,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.primary,
    required this.primaryPress,
    required this.primarySoft,
    required this.accent,
    required this.accentSoft,
    required this.keyBg,
    required this.keyBorder,
    required this.keyMod,
    required this.danger,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color divider;
  final Color dividerSoft;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color primary;
  final Color primaryPress;
  final Color primarySoft;
  final Color accent;
  final Color accentSoft;
  final Color keyBg;
  final Color keyBorder;
  final Color keyMod;
  final Color danger;

  static const light = AppColors(
    bg: Color(0xFFFAF8F5),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F1ED),
    surface3: Color(0xFFE9E6E0),
    divider: Color(0xFFE1DDD7),
    dividerSoft: Color(0xFFEDEAE4),
    ink: Color(0xFF2A2620),
    ink2: Color(0xFF5C554C),
    ink3: Color(0xFF8B837A),
    primary: Color(0xFF1FA567),
    primaryPress: Color(0xFF1A8B57),
    primarySoft: Color(0xFFE3F2E9),
    accent: Color(0xFF4E9FD4),
    accentSoft: Color(0xFFE6EFF6),
    keyBg: Color(0xFFFFFFFF),
    keyBorder: Color(0xFFDAD6CF),
    keyMod: Color(0xFFEDEAE4),
    danger: Color(0xFFC4503C),
  );

  static const dark = AppColors(
    bg: Color(0xFF14161B),
    surface: Color(0xFF1F232A),
    surface2: Color(0xFF272C34),
    surface3: Color(0xFF30353F),
    divider: Color(0xFF373D47),
    dividerSoft: Color(0xFF2B313A),
    ink: Color(0xFFF5F3F0),
    ink2: Color(0xFFC6C2BC),
    ink3: Color(0xFF8D8983),
    primary: Color(0xFF34BC7A),
    primaryPress: Color(0xFF2BA169),
    primarySoft: Color(0xFF1E3A2C),
    accent: Color(0xFF69AFDC),
    accentSoft: Color(0xFF243A47),
    keyBg: Color(0xFF272C34),
    keyBorder: Color(0xFF3B414C),
    keyMod: Color(0xFF222730),
    danger: Color(0xFFE0795E),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? divider,
    Color? dividerSoft,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? primary,
    Color? primaryPress,
    Color? primarySoft,
    Color? accent,
    Color? accentSoft,
    Color? keyBg,
    Color? keyBorder,
    Color? keyMod,
    Color? danger,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      divider: divider ?? this.divider,
      dividerSoft: dividerSoft ?? this.dividerSoft,
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      primary: primary ?? this.primary,
      primaryPress: primaryPress ?? this.primaryPress,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      keyBg: keyBg ?? this.keyBg,
      keyBorder: keyBorder ?? this.keyBorder,
      keyMod: keyMod ?? this.keyMod,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dividerSoft: Color.lerp(dividerSoft, other.dividerSoft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPress: Color.lerp(primaryPress, other.primaryPress, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      keyBg: Color.lerp(keyBg, other.keyBg, t)!,
      keyBorder: Color.lerp(keyBorder, other.keyBorder, t)!,
      keyMod: Color.lerp(keyMod, other.keyMod, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Spacing scale, radii and tap-target minimums (IMPLEMENTATION_PLAN §6.2).
class AppTokens {
  const AppTokens._();

  // 4 / 8 / 12 / 16 / 24 / 32 / 48 spacing scale.
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;

  // Radii.
  static const double rKey = 18;
  static const double rCard = 22;
  static const double rMessage = 24;
  static const double rPill = 999;

  /// Minimum tap target (design spec asks 60, HandySpeak uses 72).
  static const double minTap = 72;
}

/// Convenience accessor: `context.colors`.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  const AppTheme._();

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: c.primary,
        surface: c.surface,
        brightness: brightness,
      ),
      extensions: [c],
      textTheme: base.textTheme.apply(
        bodyColor: c.ink,
        displayColor: c.ink,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
}
