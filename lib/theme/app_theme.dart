import 'package:flutter/material.dart';

/// 이 파일은 색·글꼴·간격·모양만 정의합니다. 앱의 동작(상태 관리, API 호출,
/// 키 입력 처리 등)과는 아무 관련이 없습니다.
/// 색상 "코드"(r/g/b/y)와 백엔드로 보내는 값은 전혀 바뀌지 않았습니다.
class AppColors {
  /// 화면 전체 바탕 (시안: body background)
  static const background = Color(0xFFF5F6F8);

  /// 콘텐츠가 올라가는 흰 카드
  static const surface = Color(0xFFFFFFFF);

  /// 카드/입력요소 테두리
  static const border = Color(0xFFE2E5E9);

  /// 본문 잉크색 (순검정 대신 차콜 — 700nit 고휘도 화면에서 눈부심이 덜함)
  static const ink = Color(0xFF34383F);

  /// 보조 텍스트
  static const muted = Color(0xFF8B9098);

  /// 아직 색을 고르지 않은 키캡 자리
  static const tileEmpty = Color(0xFFEDEFF2);

  /// 진행 표시 등 포인트 컬러
  static const accent = Color(0xFF5FC494);

  /// 품절/오류 안내 (순빨강 대신 시안 핑크를 진하게)
  static const danger = Color(0xFFD9536B);

  /// 비활성(품절) 요소용 회색 계열
  static const disabledBg = Color(0xFFF0F1F4);
  static const disabledLine = Color(0xFFC9CDD4);
  static const disabledText = Color(0xFFA7ACB4);

  // --- 아래 6색은 기존 코드에서 쓰던 이름을 그대로 두고 값만 시안 팔레트로
  //     교체한 것입니다. (참조하는 화면 코드를 건드리지 않기 위함)
  static const coral = Color(0xFFF39CA9);
  static const orange = Color(0xFFFFC79A);
  static const purple = Color(0xFFBDB4F0);
  static const yellow = Color(0xFFFFDF82);
  static const green = Color(0xFF99E3BD);
  static const blue = Color(0xFF91D4EE);
}

/// 키캡 색상 — 시안 팔레트.
/// 코드(r/y/g/b)와 백엔드 전송값(red/yellow/green/blue)은 그대로입니다.
class KeycapColors {
  static const red = Color(0xFFF39CA9); // 화면 표기는 '핑크'
  static const yellow = Color(0xFFFFDF82);
  static const green = Color(0xFF99E3BD);
  static const blue = Color(0xFF91D4EE);
}

/// 판(케이스) 색상.
/// 시안은 판과 키캡에 같은 팔레트를 쓰고, 대신 키캡에 입체(하이라이트+아랫턱)
/// 처리를 넣어 같은 색이어도 키캡 실루엣이 또렷하게 보이도록 합니다.
/// (`Keycap` 위젯이 그 입체 처리를 담당합니다.)
/// 다만 완전히 동일한 색이면 판 위에서 경계가 약해지므로, 판만 아주 살짝
/// 톤을 내려 같은 계열끼리도 층이 보이게 했습니다.
class BoardColors {
  static const red = Color(0xFFE98A99);
  static const yellow = Color(0xFFF5CE64);
  static const green = Color(0xFF7ED4A6);
  static const blue = Color(0xFF74C3E4);

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

/// ---------------------------------------------------------------------------
/// 화면 규격 — UHD 4K 세로 설치 (2160 x 3840)
/// ---------------------------------------------------------------------------
/// [세로 전환] 키오스크를 세로로 세워 쓰기로 해서 설계 캔버스를
/// 1920 x 1080(가로 16:9) → 1080 x 1920(세로 9:16)으로 바꿨습니다.
/// 화면 코드는 전부 아래 "설계 캔버스"(1080 x 1920) 좌표로 작성하고,
/// [KioskScaler] 가 실제 해상도에 맞춰 통째로 비율 확대/축소합니다.
///   · 2160 x 3840 네이티브(배율 100%) → 2.0배로 확대
///   · 1080 x 1920 (배율 200% / 레티나) → 1.0배
/// 어느 쪽이든 화면에 보이는 결과는 완전히 같습니다.
class KioskCanvas {
  static const double width = 1080;
  static const double height = 1920;

  /// 배경과 흰 카드 사이 여백
  static const double margin = 40;

  static const double cardRadius = 36;

  /// 카드 안쪽 여백(상단은 진행바, 하단은 로고 푸터가 차지)
  /// [세로 전환] 캔버스 폭이 1920 → 1080으로 줄어서 좌우 여백도 96 → 64로
  /// 줄였습니다. (본문 폭: 1080 - margin*2 - 64*2 = 872)
  static const double cardPaddingH = 64;
  static const double cardPaddingTop = 120;
  static const double cardPaddingBottom = 136;
}

/// 실제 화면 크기와 상관없이 항상 [KioskCanvas] 비율로 보이게 감싸는 래퍼.
/// 4K 키오스크에서 UI가 작게 보이는 문제를 이 한 겹으로 해결합니다.
class KioskScaler extends StatelessWidget {
  final Widget child;
  const KioskScaler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.background,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: SizedBox(
            width: KioskCanvas.width,
            height: KioskCanvas.height,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 타이포그래피 — 시안(Pretendard) 기준, 설계 캔버스 1920 x 1080 스케일
/// ---------------------------------------------------------------------------
class AppTextStyles {
  static const String fontFamily = 'Pretendard';

  /// 'STEP 01 / 06' 같은 단계 표시
  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 21,
    fontWeight: FontWeight.w700,
    letterSpacing: 5,
    color: AppColors.muted,
  );

  /// 화면 제목
  static const heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 56,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    height: 1.25,
    color: AppColors.ink,
  );

  /// 안내 문구
  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 25,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );

  /// 카드/버튼 위의 강조 텍스트
  static const strong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
}

/// ---------------------------------------------------------------------------
/// 공통 장식(모양) 헬퍼
/// ---------------------------------------------------------------------------
class AppDeco {
  /// 시안의 흰 카드 (배경 위에 얹히는 판)
  static BoxDecoration get card => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(KioskCanvas.cardRadius),
        border: Border.all(color: AppColors.border, width: 2),
      );

  /// 시안의 얇은 테두리 박스 (보기 항목, 뱃지 등)
  static BoxDecoration outlined({
    double radius = 20,
    Color? borderColor,
    Color? fill,
    double width = 2,
  }) =>
      BoxDecoration(
        color: fill ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border:
            Border.all(color: borderColor ?? AppColors.border, width: width),
      );

  /// 시안의 '시작하기' 버튼 — 아래로 두툼한 하드 섀도가 달린 버튼
  static BoxDecoration pushButton({
    Color fill = AppColors.surface,
    Color line = AppColors.ink,
    double radius = 24,
    double depth = 10,
  }) =>
      BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line, width: 3),
        boxShadow: [
          BoxShadow(color: line, offset: Offset(0, depth), blurRadius: 0),
        ],
      );

  /// 완성된 보드에 쓰는 오프셋 그림자 (시안: box-shadow 10px 10px 0)
  static List<BoxShadow> get plateShadow => const [
        BoxShadow(color: AppColors.ink, offset: Offset(18, 18), blurRadius: 0),
      ];
}

/// ---------------------------------------------------------------------------
/// 키캡 — 시안의 입체 키캡(윗면 하이라이트 + 아랫턱 + 바닥 그림자)
/// ---------------------------------------------------------------------------
/// 판과 키캡이 같은 색 계열이어도 실루엣이 또렷하게 보이도록 하는 장치입니다.
class Keycap extends StatelessWidget {
  final Color color;
  final String letter;

  /// 지금 커서가 놓인(또는 수정 중인) 키캡이면 두꺼운 잉크 테두리
  final bool selected;

  /// 아직 색을 고르지 않은 자리인지
  final bool empty;

  final double width;
  final double height;
  final double fontSize;

  const Keycap({
    super.key,
    required this.color,
    required this.letter,
    this.selected = false,
    this.empty = false,
    this.width = 132,
    this.height = 148,
    this.fontSize = 46,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(width * 0.11);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(
          color:
              selected ? AppColors.ink : AppColors.ink.withValues(alpha: 0.18),
          width: selected ? 5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.22),
            offset: const Offset(0, 7),
            blurRadius: 9,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // 윗면 하이라이트
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: height * 0.07,
              child: ColoredBox(
                color: Colors.white.withValues(alpha: empty ? 0.5 : 0.62),
              ),
            ),
            // 왼쪽 측면 하이라이트
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: width * 0.055,
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.26),
              ),
            ),
            // 오른쪽 측면 그늘
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: width * 0.055,
              child: ColoredBox(
                color: AppColors.ink.withValues(alpha: 0.07),
              ),
            ),
            // 아랫턱
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: height * 0.105,
              child: ColoredBox(
                color: AppColors.ink.withValues(alpha: 0.15),
              ),
            ),
            Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontFamily: AppTextStyles.fontFamily,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: empty ? AppColors.muted : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 숫자 키 힌트 뱃지 (시안: 흰 배경 + 얇은 테두리 + 숫자)
class KeyNumBadge extends StatelessWidget {
  final String label;
  final bool filled; // true면 잉크 배경 + 흰 숫자
  final bool disabled;
  final double size;
  final double fontSize;

  const KeyNumBadge({
    super.key,
    required this.label,
    this.filled = false,
    this.disabled = false,
    this.size = 46,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final bg = disabled
        ? AppColors.disabledBg
        : (filled ? AppColors.ink : AppColors.surface);
    final fg = disabled
        ? AppColors.disabledText
        : (filled ? Colors.white : AppColors.ink);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: filled
            ? null
            : Border.all(
                color: disabled ? AppColors.disabledLine : AppColors.border,
                width: 2,
              ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// 품절 표시 pill
class SoldOutPill extends StatelessWidget {
  final String text;
  final double fontSize;
  const SoldOutPill({super.key, this.text = '재고 없음', this.fontSize = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.disabledBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.disabledLine, width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.disabledText,
        ),
      ),
    );
  }
}

class AppTheme {
  static ThemeData get themeData {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        surface: AppColors.surface,
      ),
    );
  }
}
