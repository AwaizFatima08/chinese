import 'package:flutter/material.dart';

/// Brand colours. Everything else derives from the colour scheme.
class Brand {
  const Brand._();

  static const vermilion = Color(0xFFC8372D);
  static const jade = Color(0xFF2E8B6E);
  static const gold = Color(0xFFE0A526);
  static const ink = Color(0xFF241B16);
  static const paper = Color(0xFFFBF6EE);
}

/// Colours that carry meaning beyond the Material scheme.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.tones,
    required this.gold,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;

  /// Colours for tones 1-4 and neutral (index 4).
  final List<Color> tones;
  final Color gold;

  static const light = AppColors(
    success: Color(0xFF1F7A5C),
    onSuccess: Colors.white,
    successContainer: Color(0xFFD7F0E4),
    warning: Color(0xFFB36B00),
    tones: [
      Color(0xFFD33F3F), // 1 high flat
      Color(0xFFD27A00), // 2 rising
      Color(0xFF2F8F4E), // 3 dip
      Color(0xFF2D6CC0), // 4 falling
      Color(0xFF6B6B6B), // neutral
    ],
    gold: Brand.gold,
  );

  static const dark = AppColors(
    success: Color(0xFF6FD1A8),
    onSuccess: Color(0xFF00382A),
    successContainer: Color(0xFF12382C),
    warning: Color(0xFFFFB95C),
    tones: [
      Color(0xFFFF8A8A),
      Color(0xFFFFB454),
      Color(0xFF7FD79B),
      Color(0xFF8FB8FF),
      Color(0xFFB5B5B5),
    ],
    gold: Brand.gold,
  );

  /// Colour for [tone] (1-4; anything else is neutral).
  Color toneColor(int tone) => tones[(tone >= 1 && tone <= 4) ? tone - 1 : 4];

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    List<Color>? tones,
    Color? gold,
  }) => AppColors(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    successContainer: successContainer ?? this.successContainer,
    warning: warning ?? this.warning,
    tones: tones ?? this.tones,
    gold: gold ?? this.gold,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      other is AppColors ? (t < 0.5 ? this : other) : this;
}

extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: Brand.vermilion,
      brightness: Brightness.light,
      surface: Brand.paper,
    ).copyWith(secondary: Brand.jade),
    AppColors.light,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: Brand.vermilion,
      brightness: Brightness.dark,
    ).copyWith(secondary: const Color(0xFF6FD1A8)),
    AppColors.dark,
  );

  static ThemeData _build(ColorScheme scheme, AppColors colors) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
