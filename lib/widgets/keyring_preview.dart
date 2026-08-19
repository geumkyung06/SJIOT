import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 키캡 키링 미리보기
class KeyringPreview extends StatelessWidget {
  final String mbti;
  final List<String> colors;
  final bool large;

  const KeyringPreview({
    super.key,
    required this.mbti,
    required this.colors,
    this.large = false,
  });

  Color _getColor(String colorName) {
    switch (colorName) {
      case 'g':
      case 'green':
        return AppColors.green;

      case 'y':
      case 'yellow':
        return AppColors.yellow;

      case 'b':
      case 'blue':
        return AppColors.blue;

      case 'r':
      case 'pink':
        return AppColors.pink;

      default:
        return AppColors.lightGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final letters = mbti.padRight(4, '-').substring(0, 4).split('');
    final keySize = large ? 112.0 : 78.0;
    final spacing = large ? 18.0 : 12.0;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            final colorName = index < colors.length ? colors[index] : '';

            return Padding(
              padding: EdgeInsets.only(right: index == 3 ? 0 : spacing),
              child: Keycap(
                letter: letters[index],
                color: _getColor(colorName),
                size: keySize,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class AnimatedKeyringPreview extends StatefulWidget {
  final String mbti;
  final List<String> colors;

  const AnimatedKeyringPreview({
    super.key,
    required this.mbti,
    required this.colors,
  });

  @override
  State<AnimatedKeyringPreview> createState() => _AnimatedKeyringPreviewState();
}

class _AnimatedKeyringPreviewState extends State<AnimatedKeyringPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const double keySize = 78;
  static const double spacing = 12;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColor(String colorName) {
    switch (colorName) {
      case 'g':
      case 'green':
        return AppColors.green;

      case 'y':
      case 'yellow':
        return AppColors.yellow;

      case 'b':
      case 'blue':
        return AppColors.blue;

      case 'r':
      case 'pink':
        return AppColors.pink;

      default:
        return AppColors.lightGray;
    }
  }

  double _getKeyOffset(int index, double animationValue) {
    // 각 키캡이 차례대로 시작
    final start = index * 0.19;
    final end = start + 0.34;

    if (animationValue < start || animationValue > end) {
      return 0;
    }

    final progress = (animationValue - start) / (end - start);

    // 0 → 1 → 0 형태의 부드러운 움직임
    final wave = sin(progress * pi);

    return -36 * wave;
  }

  @override
  Widget build(BuildContext context) {
    final letters = widget.mbti.padRight(4, '-').substring(0, 4).split('');

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: keySize + 55,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (index) {
              final colorName = index < widget.colors.length
                  ? widget.colors[index]
                  : '';

              final offsetY = _getKeyOffset(index, _controller.value);

              return Padding(
                padding: EdgeInsets.only(right: index == 3 ? 0 : spacing),
                child: Transform.translate(
                  offset: Offset(0, offsetY),
                  child: Keycap(
                    letter: letters[index],
                    color: _getColor(colorName),
                    size: keySize,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// 키캡 하나
class Keycap extends StatelessWidget {
  final String letter;
  final Color color;
  final double size;

  const Keycap({
    super.key,
    required this.letter,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final bottomColor = Color.lerp(color, AppColors.black, 0.14)!;

    return Container(
      width: size,
      height: size + 7,
      decoration: BoxDecoration(
        color: bottomColor,
        borderRadius: BorderRadius.circular(7),
      ),
      padding: const EdgeInsets.only(bottom: 7),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 2,
          ),
        ),
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }
}
