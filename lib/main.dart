import 'package:flutter/material.dart';
import 'device_app.dart';
import 'theme/app_colors.dart';
import 'widgets/app_buttons.dart';
import 'widgets/error_badge.dart';
import 'widgets/screen_canvas.dart';

void main() {
  runApp(const DeviceApp());
}

/// 오류 화면 공통 레이아웃
class ErrorPageLayout extends StatelessWidget {
  final String title;
  final String description;
  final String errorCode;
  final String leftButtonText;
  final String rightButtonText;
  final VoidCallback onLeftPressed;
  final VoidCallback onRightPressed;

  const ErrorPageLayout({
    super.key,
    required this.title,
    required this.description,
    required this.errorCode,
    required this.leftButtonText,
    required this.rightButtonText,
    required this.onLeftPressed,
    required this.onRightPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ScreenCanvas.column(
      children: [
        const ErrorBadge(),

        const SizedBox(height: 26),

        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 68,
            height: 1.12,
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
        ),

        const SizedBox(height: 24),

        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 25,
            height: 1.65,
            color: AppColors.textSub,
          ),
        ),

        const SizedBox(height: 48),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 330,
              height: 96,
              child: PrimaryButton(
                text: leftButtonText,
                onPressed: onLeftPressed,
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 330,
              height: 96,
              child: OutlineButton(
                text: rightButtonText,
                onPressed: onRightPressed,
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        ErrorCodeChip(errorCode),
      ],
    );
  }
}
