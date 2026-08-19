import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 왼쪽 위 조립대 번호
class WorkstationHeader extends StatelessWidget {
  final String workstationNumber;

  const WorkstationHeader({super.key, required this.workstationNumber});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1,
          letterSpacing: 0,
        ),
        children: [
          const TextSpan(
            text: '조립대 ',
            style: TextStyle(color: AppColors.gray),
          ),
          TextSpan(
            text: workstationNumber,
            style: const TextStyle(color: AppColors.gray),
          ),
        ],
      ),
    );
  }
}
