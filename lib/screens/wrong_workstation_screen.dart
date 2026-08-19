import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class WrongWorkstationScreen extends StatefulWidget {
  final String currentWorkstation;
  final String assignedWorkstation;
  final VoidCallback onAutoReturn;

  const WrongWorkstationScreen({
    super.key,
    required this.currentWorkstation,
    required this.assignedWorkstation,
    required this.onAutoReturn,
  });

  @override
  State<WrongWorkstationScreen> createState() => _WrongWorkstationScreenState();
}

class _WrongWorkstationScreenState extends State<WrongWorkstationScreen> {
  int secondsLeft = 7;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  Future<void> _startCountdown() async {
    while (secondsLeft > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      setState(() {
        secondsLeft--;
      });
    }

    if (mounted) {
      widget.onAutoReturn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 100, 40, 40),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                '오류',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.red,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                '잘못된 조립대입니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 60,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                '이 QR 코드는 다른 조립대에 배정되어 있습니다.\n'
                '배정된 조립대로 이동한 후 다시 스캔하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.6,
                  color: AppColors.gray,
                ),
              ),

              const SizedBox(height: 58),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WorkstationBox(
                    label: '현재 위치',
                    number: widget.currentWorkstation,
                    backgroundColor: const Color(0xFFF5D7D3),
                    numberColor: AppColors.red,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 35),
                    child: Column(
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          size: 34,
                          color: AppColors.gray,
                        ),
                        SizedBox(height: 32),
                      ],
                    ),
                  ),

                  WorkstationBox(
                    label: '배정된 조립대',
                    number: widget.assignedWorkstation,
                    backgroundColor: const Color(0xFFD9EFD7),
                    numberColor: Color(0xFF389544),
                  ),
                ],
              ),

              const SizedBox(height: 52),

              Text(
                '$secondsLeft초 후 대기 화면으로 돌아갑니다.',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray,
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'ERR_WS_MISMATCH',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.gray,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkstationBox extends StatelessWidget {
  final String label;
  final String number;
  final Color backgroundColor;
  final Color numberColor;

  const WorkstationBox({
    super.key,
    required this.label,
    required this.number,
    required this.backgroundColor,
    required this.numberColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.gray,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: AppColors.black, width: 2),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: numberColor,
            ),
          ),
        ),
      ],
    );
  }
}
