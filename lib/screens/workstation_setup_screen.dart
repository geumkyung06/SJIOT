import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/screen_canvas.dart';

class WorkstationSetupScreen extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const WorkstationSetupScreen({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ScreenCanvas.column(
      children: [
        const Text(
          '초기 설정',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: AppColors.textSub,
            letterSpacing: 5,
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          '조립대 번호',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 68,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          '선택한 번호는 앱을 종료하기 전까지 유지됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            height: 1.6,
            color: AppColors.textSub,
          ),
        ),

        const SizedBox(height: 56),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WorkstationSelectCard(
              number: '01',
              onPressed: () => onSelected('01'),
            ),
            const SizedBox(width: 24),
            WorkstationSelectCard(
              number: '02',
              onPressed: () => onSelected('02'),
            ),
            const SizedBox(width: 24),
            WorkstationSelectCard(
              number: '03',
              onPressed: () => onSelected('03'),
            ),
          ],
        ),
      ],
    );
  }
}

/// 조립대 선택 카드 — 누르는 동안 2px 테두리 + 우상단 파란 점
class WorkstationSelectCard extends StatefulWidget {
  final String number;
  final VoidCallback onPressed;

  const WorkstationSelectCard({
    super.key,
    required this.number,
    required this.onPressed,
  });

  @override
  State<WorkstationSelectCard> createState() => _WorkstationSelectCardState();
}

class _WorkstationSelectCardState extends State<WorkstationSelectCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        widget.onPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 240,
        height: 190,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: _pressed ? AppColors.text : AppColors.border,
            width: _pressed ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            if (_pressed)
              Positioned(
                top: 18,
                right: 18,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: AppColors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '조립대',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSub,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.number,
                    style: const TextStyle(
                      fontSize: 60,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
