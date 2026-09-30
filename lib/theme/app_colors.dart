import 'package:flutter/material.dart';

/// 공통 색상
class AppColors {
  // 60% — 전체 페이지 배경
  static const Color background = Color(0xFFF5F6F8);
  // 30% — 카드 · 컨테이너 · 선택 영역
  static const Color surface = Color(0xFFFFFFFF);
  // 제목 · 주요 글씨 · 버튼 채움
  static const Color text = Color(0xFF34383F);
  // 설명 · 부가 정보
  static const Color textSub = Color(0xFF8B9098);
  // 카드 테두리 · 구분선
  static const Color border = Color(0xFFE2E5E9);

  // 10% 포인트 — 실제 키캡 색상 (서버 주문 색상 코드 r · y · b · g)
  static const Color green = Color(0xFF99E3BD); // g
  static const Color yellow = Color(0xFFFFDF82); // y
  static const Color blue = Color(0xFF91D4EE); // b

  /// 키캡 red (서버 색상 코드 `r`).
  /// 팔레트상 부드러운 레드라 분홍빛으로 보이지만, 서버 코드와 맞춰 이름은 red로 쓴다.
  /// 오류 표시(오류 배지 · 경고 문구 · 오류 화면 강조색)도 이 색을 쓴다.
  static const Color red = Color(0xFFF39CA9); // r

  // 3D 보드 음영 (border ↔ textSub 사이 파생값)
  static const Color boardTop = Color(0xFFE2E5E9);
  static const Color boardSide = Color(0xFFC4C7CD);
  static const Color boardEdge = Color(0xFFB7BAC1);

  /// 서버 주문 색상 코드 → 키캡 색.
  ///
  /// 색상은 r · y · b · g 4가지로 고정. 그 외 값은 회색([border])으로 그린다.
  static Color keycap(String code) => switch (code.trim().toLowerCase()) {
    'r' => red,
    'y' => yellow,
    'b' => blue,
    'g' => green,
    _ => border,
  };
}
