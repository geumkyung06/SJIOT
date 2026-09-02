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

  // 10% 포인트 — 실제 키캡 색상
  static const Color green = Color(0xFF99E3BD);
  static const Color yellow = Color(0xFFFFDF82);
  static const Color blue = Color(0xFF91D4EE);
  static const Color pink = Color(0xFFF39CA9);

  // 3D 보드 음영 (border ↔ textSub 사이 파생값)
  static const Color boardTop = Color(0xFFE2E5E9);
  static const Color boardSide = Color(0xFFC4C7CD);
  static const Color boardEdge = Color(0xFFB7BAC1);
}
