import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '주문번호',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.gray,
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              orderNumber,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 120,
                height: 1,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),

            const SizedBox(height: 52),

            SizedBox(
              width: 330,
              height: 96,
              child: PrimaryButton(text: 'QR 코드 스캔', onPressed: onQrScan),
            ),
          ],
        ),
      ),
    );
  }
}
