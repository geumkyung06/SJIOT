import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _LogoTile(color: AppColors.coral, label: '딸'),
            SizedBox(width: 12),
            _LogoTile(color: AppColors.orange, label: '깍'),
            SizedBox(width: 12),
            _LogoTile(color: AppColors.yellow, label: 'KEY'),
            SizedBox(width: 12),
            _LogoTile(color: AppColors.green, icon: Icons.auto_awesome),
          ],
        ),
        const SizedBox(height: 32),
        const Text(
          '딸깍',
          style: TextStyle(fontSize: 88, fontWeight: FontWeight.w900, color: AppColors.ink),
        ),
        const SizedBox(height: 12),
        const Text(
          'CLICKY KEYRING STUDIO',
          style: TextStyle(fontSize: 18, letterSpacing: 6, color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Container(width: 260, height: 2, color: AppColors.ink),
        const SizedBox(height: 32),
        // '키보드 키링' -> 'MBTI 키링'
        const Text('나만의 MBTI 키링을 만들어 보세요', style: AppTextStyles.body),
        const SizedBox(height: 48),
        Container(
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
      ],
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