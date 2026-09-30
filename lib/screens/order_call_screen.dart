import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../widgets/screen_canvas.dart';

class OrderCallScreen extends StatelessWidget {
  final String orderNumber;
  final VoidCallback onQrScan;

  const OrderCallScreen({
    super.key,
    required this.orderNumber,
    required this.onQrScan,
  });

  @override
  Widget build(BuildContext context) {
    return ScreenCanvas.column(
      children: [
        Container(
          width: 640,
          padding: const EdgeInsets.fromLTRB(48, 30, 48, 30),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '주문번호',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSub,
                  letterSpacing: 5,
                ),
              ),

              const SizedBox(height: 12),

              // 주문 배정 전에는 '조립대 02' 같은 긴 문자열이 들어와 넘칠 수 있습니다.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  orderNumber,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 80,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const _KeycapColorBar(),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: 200,
          height: 70,
          child: PrimaryButton(text: 'QR 코드 스캔', onPressed: onQrScan),
        ),

        const SizedBox(height: 22),

        const Text(
          '영수증의 QR 코드를 스캔해 주세요.',
          style: TextStyle(fontSize: 17, color: AppColors.textSub),
        ),
      ],
    );
  }
}

/// 키캡 4색 바
class _KeycapColorBar extends StatelessWidget {
  const _KeycapColorBar();

  static const List<Color> _colors = [
    AppColors.green,
    AppColors.yellow,
    AppColors.blue,
    AppColors.red,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in _colors)
          Container(
            width: 40,
            height: 8,
            margin: EdgeInsets.only(right: color == _colors.last ? 0 : 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
