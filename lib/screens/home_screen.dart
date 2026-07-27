import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 00 — 시작 화면(인트로)
///
/// 애니메이션은 피그마(Figma Make) `IntroScreen`의 모션을 이식한 것입니다.
/// (참고: src/app/App.tsx > function IntroScreen())
///
/// 구현 방식(중요): 커스텀 AnimationController + Interval + Matrix4 조합 대신,
/// Flutter 내장 "암시적(implicit) 애니메이션" 위젯만 사용합니다.
///   - AnimatedOpacity : 페이드 인
///   - AnimatedSlide    : 슬라이드 인 (오프셋은 child 크기에 대한 비율)
///   - AnimatedScale    : 구분선 scaleX 효과
/// 각 위젯은 `visible` 값이 false→true로 바뀌는 그 프레임부터 자기 duration만큼
/// 스스로 애니메이션을 새로 시작하기 때문에, 공용 컨트롤러의 시계가 화면 렌더링보다
/// 먼저 흘러버리는 문제(첫 프레임 지연으로 초반 구간이 스킵되는 문제)가 구조적으로
/// 발생하지 않습니다. 순차 등장은 각 요소의 `visible`을 서로 다른 딜레이의
/// `Future.delayed`로 켜주는 방식으로 구현합니다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // 순차 등장 여부 플래그들 (초기값 false = 숨김/오프셋 상태)
  final List<bool> _tileVisible = [false, false, false, false];
  bool _titleVisible = false;
  bool _subtitleVisible = false;
  bool _dividerVisible = false;
  bool _bodyVisible = false;
  bool _enterVisible = false;

  // ENTER 배지 무한 펄스(깜빡임). 피그마: 1.8s 주기로 opacity 1 → 0.4 → 1 반복.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseOpacity;

  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900), // 0.9s 왕복 = 1.8s 주기
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 피그마의 delay 값(초)을 그대로 ms로 옮겨 순차 등장시킵니다.
    _scheduleReveal(60, () => setState(() => _tileVisible[0] = true));
    _scheduleReveal(130, () => setState(() => _tileVisible[1] = true));
    _scheduleReveal(200, () => setState(() => _tileVisible[2] = true));
    _scheduleReveal(270, () => setState(() => _tileVisible[3] = true));
    _scheduleReveal(180, () => setState(() => _titleVisible = true));
    _scheduleReveal(260, () => setState(() => _subtitleVisible = true));
    _scheduleReveal(320, () => setState(() => _dividerVisible = true));
    _scheduleReveal(380, () => setState(() => _bodyVisible = true));
    _scheduleReveal(460, () => setState(() => _enterVisible = true));
  }

  void _scheduleReveal(int delayMs, void Function() reveal) {
    final timer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) reveal();
    });
    _timers.add(timer);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EnterFade(
              visible: _tileVisible[0],
              slideOffset: const Offset(0, -0.6),
              child: const _LogoTile(color: AppColors.coral, label: '딸'),
            ),
            const SizedBox(width: 12),
            _EnterFade(
              visible: _tileVisible[1],
              slideOffset: const Offset(0, -0.6),
              child: const _LogoTile(color: AppColors.orange, label: '깍'),
            ),
            const SizedBox(width: 12),
            _EnterFade(
              visible: _tileVisible[2],
              slideOffset: const Offset(0, -0.6),
              child: const _LogoTile(color: AppColors.yellow, label: 'KEY'),
            ),
            const SizedBox(width: 12),
            _EnterFade(
              visible: _tileVisible[3],
              slideOffset: const Offset(0, -0.6),
              child: const _LogoTile(color: AppColors.green, icon: Icons.auto_awesome),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _EnterFade(
          visible: _titleVisible,
          slideOffset: const Offset(0, 0.25),
          child: const Text(
            '딸깍',
            style: TextStyle(fontSize: 88, fontWeight: FontWeight.w900, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: _subtitleVisible ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: const Text(
            'CLICKY KEYRING STUDIO',
            style: TextStyle(fontSize: 18, letterSpacing: 6, color: AppColors.muted, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedScale(
          scale: _dividerVisible ? 1 : 0,
          alignment: Alignment.centerLeft,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          child: Container(width: 260, height: 2, color: AppColors.ink),
        ),
        const SizedBox(height: 32),
        AnimatedOpacity(
          opacity: _bodyVisible ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: const Text('나만의 MBTI 키링을 만들어 보세요', style: AppTextStyles.body),
        ),
        const SizedBox(height: 48),
        _EnterFade(
          visible: _enterVisible,
          slideOffset: const Offset(0, 0.5),
          child: AnimatedBuilder(
            animation: _pulseOpacity,
            builder: (context, child) => Opacity(opacity: _pulseOpacity.value, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppColors.muted,
                    child: const Text('ENTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  const Text('시작하기', style: TextStyle(fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// opacity + slide(비율 offset) 페이드인을 함께 처리하는 공용 래퍼.
/// AnimatedSlide / AnimatedOpacity(둘 다 Flutter 표준 내장 위젯) 조합만 사용합니다.
class _EnterFade extends StatelessWidget {
  final bool visible;
  final Offset slideOffset; // 시작 위치 (child 크기 대비 비율). 예: (0,-0.6) = 위에서 등장
  final Widget child;

  const _EnterFade({
    required this.visible,
    required this.slideOffset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : slideOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  final Color color;
  final String? label;
  final IconData? icon;
  const _LogoTile({required this.color, this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, border: Border.all(color: AppColors.ink, width: 2)),
      child: icon != null
          ? Icon(icon, color: Colors.white, size: 26)
          : Text(label ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
    );
  }
}