import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_buttons.dart';
import '../widgets/keycap_board_3d.dart';

class AssemblingScreen extends StatefulWidget {
  final String mbti;
  final List<String> colors;
  final String? orderNumber;
  final VoidCallback onComplete;

  const AssemblingScreen({
    super.key,
    required this.mbti,
    required this.colors,
    required this.onComplete,
    this.orderNumber,
  });

  @override
  State<AssemblingScreen> createState() => _AssemblingScreenState();
}

class _AssemblingScreenState extends State<AssemblingScreen> {
  /// 조립 중 화면을 유지하는 최대 시간
  /// static const Duration _assemblyTimeout = Duration(minutes: 5);
  static const Duration _assemblyTimeout = Duration(seconds: 10);

  Timer? _assemblyTimer;

  final AudioPlayer _alertPlayer = AudioPlayer();

  /// 확인 팝업이 중복으로 표시되는 것을 방지합니다.
  bool _isCheckDialogOpen = false;

  @override
  void dispose() {
    _assemblyTimer?.cancel();
    _alertPlayer.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    /// 조립 중 화면에 들어오면 5분 타이머를 시작합니다.
    _startAssemblyTimer();
  }

  void _startAssemblyTimer() {
    /// 기존 타이머가 남아 있다면 먼저 취소합니다.
    _assemblyTimer?.cancel();

    _assemblyTimer = Timer(_assemblyTimeout, _showAssemblyCheckDialog);
  }

  Future<void> _showAssemblyCheckDialog() async {
    if (!mounted || _isCheckDialogOpen) {
      return;
    }

    _isCheckDialogOpen = true;

    await _alertPlayer.setReleaseMode(ReleaseMode.loop);

    await _alertPlayer.play(
      AssetSource('sounds/assembly_warning.mp3'),
      volume: 0.7,
    );

    if (!mounted) {
      return;
    }

    final bool? stillAssembling = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const AssemblyCheckDialog(autoCompleteSeconds: 10);
      },
    );

    /// 팝업이 닫히면 경고음 정지
    await _alertPlayer.stop();

    _isCheckDialogOpen = false;

    if (!mounted) {
      return;
    }

    if (stillAssembling == true) {
      /// 아직 조립 중이면 다시 타이머 시작
      _startAssemblyTimer();
    } else {
      /// 아무 응답이 없으면 자동 완료
      widget.onComplete();
    }
  }

  void _completeAssembly() {
    /// 직접 조립 완료 버튼을 눌렀을 때 타이머를 취소합니다.
    _assemblyTimer?.cancel();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final String caption = widget.orderNumber == null
        ? widget.mbti
        : '${widget.orderNumber} · ${widget.mbti}';

    // 샘플 기준 1440x900 좌표계를 그대로 두고 화면 크기에 맞춰 축소합니다.
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(90, 130, 90, 70),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 1260,
            height: 700,
            child: Row(
              children: [
                SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '진행 중',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSub,
                          letterSpacing: 5,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        '조립 중',
                        style: TextStyle(
                          fontSize: 76,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),

                      const SizedBox(height: 22),

                      const Text(
                        '부품을 순서대로 끼워 주세요.\n'
                        '완료되면 아래 버튼을 눌러 주세요.',
                        style: TextStyle(
                          fontSize: 25,
                          height: 1.6,
                          color: AppColors.textSub,
                        ),
                      ),

                      const SizedBox(height: 44),

                      SizedBox(
                        width: 380,
                        height: 96,
                        child: PrimaryButton(
                          text: '조립 완료',
                          onPressed: _completeAssembly,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 72),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: KeycapBoard3D(
                            mbti: widget.mbti,
                            colors: widget.colors,
                            mountedCount: 3,
                            animateDrop: true,
                          ),
                        ),

                        const SizedBox(height: 28),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '주문번호',
                              style: TextStyle(fontSize: 23, color: AppColors.textSub),
                            ),
                            Text(
                              caption,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 조립 시간이 오래 걸릴 때 표시되는 확인 팝업
class AssemblyCheckDialog extends StatefulWidget {
  final int autoCompleteSeconds;

  const AssemblyCheckDialog({super.key, required this.autoCompleteSeconds});

  @override
  State<AssemblyCheckDialog> createState() => _AssemblyCheckDialogState();
}

class _AssemblyCheckDialogState extends State<AssemblyCheckDialog> {
  Timer? _countdownTimer;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();

    _secondsLeft = widget.autoCompleteSeconds;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCountdown();
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft <= 1) {
        timer.cancel();

        /// false는 자동 완료를 의미합니다.
        Navigator.of(context).pop(false);
        return;
      }

      setState(() {
        _secondsLeft--;
      });
    });
  }

  void _continueAssembly() {
    _countdownTimer?.cancel();

    /// true는 아직 조립 중임을 의미합니다.
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(36, 36, 36, 0),
        contentPadding: const EdgeInsets.fromLTRB(36, 22, 36, 28),
        actionsPadding: const EdgeInsets.fromLTRB(36, 0, 36, 36),
        title: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                size: 30,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '아직 조립 중인가요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
          ],
        ),
        content: Text(
          '$_secondsLeft초 동안 응답이 없으면\n'
          '자동으로 조립 완료 처리됩니다.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            height: 1.5,
            color: AppColors.textSub,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 76,
            child: PrimaryButton(
              text: '아직 조립 중이에요',
              onPressed: _continueAssembly,
            ),
          ),
        ],
      ),
    );
  }
}
