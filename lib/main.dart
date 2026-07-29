import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'services/api_service.dart';
import 'models/order_info.dart';

void main() {
  runApp(const DeviceApp());
}

/// 디바이스 앱에서 사용할 화면 상태
enum DeviceStep {
  workstationSetup,
  waiting,
  authenticated,
  assembling,
  completed,
  invalidQr,
  wrongWorkstation,
}

class DeviceApp extends StatelessWidget {
  const DeviceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '조립대 디바이스 앱',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.black),
      ),
      home: const DeviceRoot(),
    );
  }
}

class DeviceRoot extends StatefulWidget {
  const DeviceRoot({super.key});

  @override
  State<DeviceRoot> createState() => _DeviceRootState();
}

class _DeviceRootState extends State<DeviceRoot> {
  final ApiService _api = ApiService();

  DeviceStep _currentStep = DeviceStep.workstationSetup;

  /// 앱을 종료하기 전까지 유지되는 조립대 번호
  String? _workstationNumber;

  /// 테스트용 주문 정보
  ///
  /// 현재는 QR 스캔 기능이 없으므로 임시 데이터를 사용합니다.
  /// 나중에는 QR 코드의 JSON 데이터를 OrderInfo.fromJson()으로 변환합니다.
  OrderInfo _order = const OrderInfo(
    orderId: 'ORD-20260728-0001',
    mbti: 'ISTJ',
    colors: ['green', 'yellow', 'blue', 'pink'],
    assignedWorkstation: 1,
  );

  void _selectWorkstation(String number) {
    setState(() {
      _workstationNumber = number;
      _currentStep = DeviceStep.waiting;
    });
  }

  void _processTestQr() {
    final String currentWorkstation = _workstationNumber ?? '';

    final String assignedWorkstation = _order.workstationLabel;

    if (currentWorkstation == assignedWorkstation) {
      _moveTo(DeviceStep.authenticated);
    } else {
      _moveTo(DeviceStep.wrongWorkstation);
    }
  }

  void _moveTo(DeviceStep step) {
    setState(() {
      _currentStep = step;
    });
  }

  void _reset() {
    setState(() {
      _currentStep = DeviceStep.waiting;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget screen;

    switch (_currentStep) {
      case DeviceStep.workstationSetup:
        screen = WorkstationSetupScreen(onSelected: _selectWorkstation);
        break;

      case DeviceStep.waiting:
        screen = WaitingScreen(
          workstationNumber: _workstationNumber ?? '--',
          onQrSuccess: _processTestQr,
          onInvalidQr: () => _moveTo(DeviceStep.invalidQr),
          onWrongWorkstation: () => _moveTo(DeviceStep.wrongWorkstation),
        );
        break;

      case DeviceStep.authenticated:
        screen = AuthenticatedScreen(
          mbti: _order.mbti,
          colors: _order.colors,
          onStart: () => _moveTo(DeviceStep.assembling),
        );
        break;

      case DeviceStep.assembling:
        screen = AssemblingScreen(
          mbti: _order.mbti,
          colors: _order.colors,
          onComplete: () => _moveTo(DeviceStep.completed),
        );
        break;

      case DeviceStep.completed:
        screen = CompletedScreen(
          mbti: _order.mbti,
          colors: _order.colors,
          onRestart: _reset,
        );
        break;

      case DeviceStep.invalidQr:
        screen = InvalidQrScreen(
          onRetry: _reset,
          onCallStaff: () {
            _showStaffDialog();
          },
        );
        break;

      case DeviceStep.wrongWorkstation:
        screen = WrongWorkstationScreen(
          currentWorkstation: _workstationNumber ?? '--',
          assignedWorkstation: _order.workstationLabel,
          onAutoReturn: _reset,
        );
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: screen),

            if (_currentStep != DeviceStep.workstationSetup &&
                _workstationNumber != null)
              Positioned(
                top: 28,
                left: 48,
                child: WorkstationHeader(
                  workstationNumber: _workstationNumber!,
                ),
              ),

            /// 화면 확인용 테스트 메뉴
            Positioned(
              right: 24,
              bottom: 24,
              child: DemoMenu(
                onWaiting: () => _moveTo(DeviceStep.waiting),
                onAuthenticated: () => _moveTo(DeviceStep.authenticated),
                onAssembling: () => _moveTo(DeviceStep.assembling),
                onCompleted: () => _moveTo(DeviceStep.completed),
                onInvalidQr: () => _moveTo(DeviceStep.invalidQr),
                onWrongWorkstation: () => _moveTo(DeviceStep.wrongWorkstation),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStaffDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('직원 호출 완료'),
          content: const Text('잠시만 기다려 주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}

/// 공통 색상
class AppColors {
  static const Color background = Color(0xFFFFFAED);
  static const Color black = Color(0xFF191919);
  static const Color gray = Color(0xFF98958D);
  static const Color lightGray = Color(0xFFD9D5CB);
  static const Color red = Color(0xFFF05A42);
  static const Color green = Color(0xFF99E3BD);
  static const Color yellow = Color(0xFFFFDF82);
  static const Color blue = Color(0xFF91D4EE);
  static const Color pink = Color(0xFFF39CA9);
}

/// 왼쪽 위 조립대 번호
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

/// 0. 앱 실행 시 처음 표시되는 조립대 번호 설정 화면
class WorkstationSetupScreen extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const WorkstationSetupScreen({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '초기 설정',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.gray,
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              '조립대 번호',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 64,
                height: 1.15,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              '선택한 번호는 앱을 종료하기 전까지 유지됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, color: AppColors.gray),
            ),

            const SizedBox(height: 52),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WorkstationSelectButton(
                  number: '01',
                  onPressed: () => onSelected('01'),
                ),
                const SizedBox(width: 20),
                WorkstationSelectButton(
                  number: '02',
                  onPressed: () => onSelected('02'),
                ),
                const SizedBox(width: 20),
                WorkstationSelectButton(
                  number: '03',
                  onPressed: () => onSelected('03'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkstationSelectButton extends StatelessWidget {
  final String number;
  final VoidCallback onPressed;

  const WorkstationSelectButton({
    super.key,
    required this.number,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      height: 150,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: AppColors.black, width: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '조립대',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.gray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              number,
              style: const TextStyle(
                fontSize: 52,
                height: 1,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1. 대기 중 화면
class WaitingScreen extends StatelessWidget {
  final String workstationNumber;
  final VoidCallback onQrSuccess;
  final VoidCallback onInvalidQr;
  final VoidCallback onWrongWorkstation;

  const WaitingScreen({
    super.key,
    required this.workstationNumber,
    required this.onQrSuccess,
    required this.onInvalidQr,
    required this.onWrongWorkstation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StatusCircle(),

            const SizedBox(height: 16),

            const Text(
              '사용 가능',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.gray,
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              '조립대 $workstationNumber',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 72,
                height: 1,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              '영수증의 QR 코드를 스캔해 주세요.',
              style: TextStyle(fontSize: 20, color: AppColors.gray),
            ),

            const SizedBox(height: 42),

            /// 실제 앱에서는 QR 스캐너가 이 부분을 대신합니다.
            SizedBox(
              width: 330,
              child: PrimaryButton(text: 'QR 인증 테스트', onPressed: onQrSuccess),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: onInvalidQr,
                  child: const Text('잘못된 QR 테스트'),
                ),
                TextButton(
                  onPressed: onWrongWorkstation,
                  child: const Text('잘못된 조립대 테스트'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 대기 중 원형 표시
/// 대기 중 원형 애니메이션
class StatusCircle extends StatefulWidget {
  const StatusCircle({super.key});

  @override
  State<StatusCircle> createState() => _StatusCircleState();
}

class _StatusCircleState extends State<StatusCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _outerScale;
  late final Animation<double> _middleScale;
  late final Animation<double> _centerScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // 바깥 원
    _outerScale = Tween<double>(
      begin: 0.92,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // 가운데 원
    _middleScale = Tween<double>(begin: 0.94, end: 1.03).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 1.0, curve: Curves.easeInOut),
      ),
    );

    // 중앙 점
    _centerScale = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 바깥 원
          ScaleTransition(
            scale: _outerScale,
            child: Container(
              width: 145,
              height: 145,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.lightGray, width: 3),
              ),
            ),
          ),

          // 가운데 원
          ScaleTransition(
            scale: _middleScale,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.lightGray, width: 3),
              ),
            ),
          ),

          // 중앙 점
          ScaleTransition(
            scale: _centerScale,
            child: Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF444444),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. 인증 완료 화면
class AuthenticatedScreen extends StatelessWidget {
  final String mbti;
  final List<String> colors;
  final VoidCallback onStart;

  const AuthenticatedScreen({
    super.key,
    required this.mbti,
    required this.colors,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return DevicePageLayout(
      label: '인증 완료',
      title: 'MBTI 키캡 키링',
      children: [
        KeyringPreview(mbti: mbti, colors: colors),
        const SizedBox(height: 52),
        SizedBox(
          width: 330,
          height: 96,
          child: PrimaryButton(text: '조립 시작', onPressed: onStart),
        ),
      ],
    );
  }
}

/// 3. 조립 중 화면
class AssemblingScreen extends StatefulWidget {
  final String mbti;
  final List<String> colors;
  final VoidCallback onComplete;

  const AssemblingScreen({
    super.key,
    required this.mbti,
    required this.colors,
    required this.onComplete,
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
    return DevicePageLayout(
      label: '진행 중',
      title: '조립 중',
      children: [
        AnimatedKeyringPreview(mbti: widget.mbti, colors: widget.colors),

        const SizedBox(height: 52),

        SizedBox(
          width: 330,
          height: 96,
          child: PrimaryButton(text: '조립 완료', onPressed: _completeAssembly),
        ),
      ],
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
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.black, width: 2),
        ),
        titlePadding: const EdgeInsets.fromLTRB(36, 36, 36, 0),
        contentPadding: const EdgeInsets.fromLTRB(36, 22, 36, 28),
        actionsPadding: const EdgeInsets.fromLTRB(36, 0, 36, 36),
        title: const Column(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 54,
              color: AppColors.red,
            ),
            SizedBox(height: 20),
            Text(
              '아직 조립 중인가요?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
          ],
        ),
        content: Text(
          '$_secondsLeft초 동안 응답이 없으면\n'
          '자동으로 조립 완료 처리됩니다.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            height: 1.5,
            color: AppColors.gray,
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

/// 4. 조립 완료 화면
class CompletedScreen extends StatefulWidget {
  final String mbti;
  final List<String> colors;
  final VoidCallback onRestart;

  const CompletedScreen({
    super.key,
    required this.mbti,
    required this.colors,
    required this.onRestart,
  });

  @override
  State<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends State<CompletedScreen>
    with SingleTickerProviderStateMixin {
  int secondsLeft = 10;
  late final AnimationController _previewController;
  late final Animation<double> _previewScale;

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _previewController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _previewScale = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(parent: _previewController, curve: Curves.easeOutBack),
    );

    _previewController.forward();

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
      widget.onRestart();
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
                '완료',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gray,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                '조립 완료!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 72,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'MBTI 키캡 키링이 완성되었습니다.',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),

              const SizedBox(height: 44),

              ScaleTransition(
                scale: _previewScale,
                child: KeyringPreview(
                  mbti: widget.mbti,
                  colors: widget.colors,
                  large: true,
                ),
              ),

              const SizedBox(height: 48),

              Container(
                width: 590,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.black, width: 2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 25),
                    SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        '소지품을 꼭 챙겨가세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 42),

              Text(
                '●  조립대를 다음 사용자를 위해 초기화하는 중... '
                '$secondsLeft초',
                style: const TextStyle(fontSize: 16, color: AppColors.gray),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: widget.onRestart,
                child: const Text('지금 초기화'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 오류: 잘못된 QR
class InvalidQrScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onCallStaff;

  const InvalidQrScreen({
    super.key,
    required this.onRetry,
    required this.onCallStaff,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorPageLayout(
      title: '인식할 수 없는 QR 코드',
      description:
          '스캔한 QR 코드를 인식하지 못했습니다.\n'
          '영수증에 인쇄된 QR 코드를 사용하고 있는지 확인하세요.',
      errorCode: 'ERR_QR_INVALID',
      leftButtonText: '다시 시도',
      rightButtonText: '직원 호출',
      onLeftPressed: onRetry,
      onRightPressed: onCallStaff,
    );
  }
}

/// 오류: 잘못된 조립대
/// 오류: 잘못된 조립대
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

/// 인증 완료·조립 중 화면 공통 레이아웃
class DevicePageLayout extends StatelessWidget {
  final String label;
  final String title;
  final List<Widget> children;

  const DevicePageLayout({
    super.key,
    required this.label,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 90, 40, 40),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gray,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 64,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 100),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
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
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 60,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.6,
                  color: AppColors.gray,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 330,
                    height: 92,
                    child: PrimaryButton(
                      text: leftButtonText,
                      onPressed: onLeftPressed,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 330,
                    height: 92,
                    child: OutlineButton(
                      text: rightButtonText,
                      onPressed: onRightPressed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                errorCode,
                style: const TextStyle(
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
      case 'green':
        return AppColors.green;
      case 'yellow':
        return AppColors.yellow;
      case 'blue':
        return AppColors.blue;
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
      case 'green':
        return AppColors.green;

      case 'yellow':
        return AppColors.yellow;

      case 'blue':
        return AppColors.blue;

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

/// 키캡 아래 키링 연결선
class KeyringLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final y = 12.0;
    final startX = size.width / 8;
    final endX = size.width - startX;

    canvas.drawLine(Offset(startX, y), Offset(endX, y), linePaint);

    for (int i = 0; i < 4; i++) {
      final x = startX + ((endX - startX) / 3) * i;

      canvas.drawCircle(Offset(x, y), 8, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

/// 검은색 기본 버튼
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.black,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        textStyle: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
      ),
      child: Text(text),
    );
  }
}

/// 테두리 버튼
class OutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const OutlineButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.black,
        side: const BorderSide(color: AppColors.black, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      child: Text(text),
    );
  }
}

/// 개발 중 화면을 바로 전환하기 위한 테스트 메뉴
///
/// 실제 배포 전에는 이 위젯을 삭제하면 됩니다.
class DemoMenu extends StatelessWidget {
  final VoidCallback onWaiting;
  final VoidCallback onAuthenticated;
  final VoidCallback onAssembling;
  final VoidCallback onCompleted;
  final VoidCallback onInvalidQr;
  final VoidCallback onWrongWorkstation;

  const DemoMenu({
    super.key,
    required this.onWaiting,
    required this.onAuthenticated,
    required this.onAssembling,
    required this.onCompleted,
    required this.onInvalidQr,
    required this.onWrongWorkstation,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DeviceStep>(
      tooltip: '화면 테스트',
      icon: const Icon(Icons.developer_mode, color: AppColors.gray),
      onSelected: (step) {
        switch (step) {
          case DeviceStep.workstationSetup:
            break;

          case DeviceStep.waiting:
            onWaiting();
            break;

          case DeviceStep.authenticated:
            onAuthenticated();
            break;

          case DeviceStep.assembling:
            onAssembling();
            break;

          case DeviceStep.completed:
            onCompleted();
            break;

          case DeviceStep.invalidQr:
            onInvalidQr();
            break;

          case DeviceStep.wrongWorkstation:
            onWrongWorkstation();
            break;
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem(value: DeviceStep.waiting, child: Text('1. 대기 중')),
          PopupMenuItem(
            value: DeviceStep.authenticated,
            child: Text('2. 인증 완료'),
          ),
          PopupMenuItem(value: DeviceStep.assembling, child: Text('3. 조립 중')),
          PopupMenuItem(value: DeviceStep.completed, child: Text('4. 조립 완료')),
          PopupMenuDivider(),
          PopupMenuItem(value: DeviceStep.invalidQr, child: Text('오류: 잘못된 QR')),
          PopupMenuItem(
            value: DeviceStep.wrongWorkstation,
            child: Text('오류: 잘못된 조립대'),
          ),
        ];
      },
    );
  }
}
