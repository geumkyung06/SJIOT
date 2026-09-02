import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 왼쪽 위 조립대 번호 — 흰 알약 칩 + 상태 점
class WorkstationHeader extends StatelessWidget {
  final String workstationNumber;
  final Color statusColor;

  const WorkstationHeader({
    super.key,
    required this.workstationNumber,
    this.statusColor = AppColors.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '조립대 $workstationNumber',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1,
              color: AppColors.textSub,
            ),
          ),
        ],
      ),
    );
  }
}
