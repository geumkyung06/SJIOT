import 'package:flutter/material.dart';

/// 피그마 시안 기준 컬러 팔레트.
/// coral(=r) / orange(=o) / yellow(=y) / green(=g) / blue(=b) / purple(=p)
/// 6색이 백엔드 COLOR_LIST 코드와 매핑됩니다.
class AppColors {
  static const background = Color(0xFFFDF6E8);
  static const coral = Color(0xFFFB7185);
  static const orange = Color(0xFFFB923C);
  static const purple = Color(0xFFA78BFA);
  static const yellow = Color(0xFFFCD34D);
  static const green = Color(0xFF34D399);
  static const blue = Color(0xFF38BDF8);
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF8A8A82);
  static const tileEmpty = Color(0xFFEDEAE0);
}

class KeycapColors {
  static const red = Color(0xFFF4A7B0);
  static const yellow = Color(0xFFFDE38C);
  static const green = Color(0xFF9EE6BC);
  static const blue = Color(0xFFA9DFF4);
}

// [신규] 판(케이스) 색상 — 키캡과 같은 색 코드(r/g/b/y)를 쓰지만, 판을
// 눈에 띄게 채우면 같은 계열의 키캡과 구분이 안 되는 문제가 있었습니다
// (예: 노랑 판 + 노랑 키캡 = 거의 같은 색이라 경계가 안 보임).
// 그래서 판 색은 같은 색상을 채도/명도를 더 진하게 만든 버전을 씁니다.
// 코드(r/g/b/y)와 백엔드로 보내는 값(red/yellow/green/blue)은 전혀
// 바뀌지 않고, "화면에 칠하는 실제 색"만 이렇게 더 진한 톤을 씁니다.
class BoardColors {
  static const red = Color(0xFFE8607A); // KeycapColors.red보다 진한 핑크
  static const yellow = Color(0xFFE8B93A); // KeycapColors.yellow보다 진한 옐로우
  static const green = Color(0xFF3FAE7A); // KeycapColors.green보다 진한 그린
  static const blue = Color(0xFF3E8FC2); // KeycapColors.blue보다 진한 블루

  static Color of(String code) {
    switch (code) {
      case 'r':
        return red;
      case 'y':
        return yellow;
      case 'g':
        return green;
      case 'b':
        return blue;
      default:
        return green;
    }
  }
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
