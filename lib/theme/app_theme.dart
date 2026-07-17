import 'package:flutter/material.dart';

/// 피그마 시안 기준 컬러 팔레트.
/// coral(=r) / orange(=o) / yellow(=y) / green(=g) / blue(=b) / purple(=p)
/// 6색이 백엔드 COLOR_LIST 코드와 매핑됩니다.
class AppColors {
  static const background = Color(0xFFFDF6E8);
  static const coral = Color(0xFFE8593C);
  static const orange = Color(0xFFE8933C);
  static const purple = Color(0xFF9B6BC7);
  static const yellow = Color(0xFFF0C93C);
  static const green = Color(0xFF6FBF73);
  static const blue = Color(0xFF4A90D9);
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF8A8A82);
  static const tileEmpty = Color(0xFFEDEAE0);
}

class AppTextStyles {
  static const label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 4,
    color: AppColors.muted,
  );

  static const heading = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontSize: 16,
    color: AppColors.muted,
  );
}

class AppTheme {
  static ThemeData get themeData {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.coral),
    );
  }
}