import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const DeviceApp());
}

/// 조립대 번호
///
/// 조립대마다 앱을 설치할 때 이 값만 바꾸면 됩니다.
/// 조립대 01 → '01'
/// 조립대 02 → '02'
/// 조립대 03 → '03'
const String workstationNumber = '03';

/// 디바이스 앱에서 사용할 화면 상태
enum DeviceStep {
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

  DeviceStep _currentStep = DeviceStep.waiting;

  /// 테스트용 주문 정보
  ///
  /// 나중에는 QR 코드 또는 서버 응답에서 가져오게 됩니다.
  String _mbti = 'ISTJ';

  List<String> _colors = ['green', 'yellow', 'blue', 'pink'];

  /// 잘못된 조립대 오류 화면에서 보여줄 배정 조립대
  String _assignedWorkstation = '01';

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
      case DeviceStep.waiting:
        screen = WaitingScreen(
          onQrSuccess: () => _moveTo(DeviceStep.authenticated),
          onInvalidQr: () => _moveTo(DeviceStep.invalidQr),
          onWrongWorkstation: () => _moveTo(DeviceStep.wrongWorkstation),
        );
        break;

      case DeviceStep.authenticated:
        screen = AuthenticatedScreen(
          mbti: _mbti,
          colors: _colors,
          onStart: () => _moveTo(DeviceStep.assembling),
        );
        break;

      case DeviceStep.assembling:
        screen = AssemblingScreen(
          mbti: _mbti,
          colors: _colors,
          onComplete: () => _moveTo(DeviceStep.completed),
        );
        break;

      case DeviceStep.completed:
        screen = CompletedScreen(
          mbti: _mbti,
          colors: _colors,
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
          assignedWorkstation: _assignedWorkstation,
          onRetry: _reset,
          onHelp: () {
            _showStaffDialog();
          },
        );
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: screen),

            const Positioned(
              top: 28,
              left: 48,
              child: WorkstationHeader(workstationNumber: workstationNumber),
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
          title: const Text('직원을 호출했습니다'),
          content: const Text('잠시만 기다려 주세요.\n직원이 조립대를 확인하겠습니다.'),
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
class WorkstationHeader extends StatelessWidget {
  final String workstationNumber;

  const WorkstationHeader({super.key, required this.workstationNumber});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '조립대',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.gray,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          workstationNumber,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

/// 1. 대기 중 화면
class WaitingScreen extends StatelessWidget {
  final VoidCallback onQrSuccess;
  final VoidCallback onInvalidQr;
  final VoidCallback onWrongWorkstation;

  const WaitingScreen({
    super.key,
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
                fontWeight: FontWeight.w600,
                color: AppColors.gray,
                letterSpacing: 4,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              '대기 중',
              textAlign: TextAlign.center,
              style: TextStyle(
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
class AssemblingScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return DevicePageLayout(
      label: '진행 중',
      title: '조립 중',
      children: [
        KeyringPreview(mbti: mbti, colors: colors),
        const SizedBox(height: 52),
        SizedBox(
          width: 330,
          height: 96,
          child: PrimaryButton(text: '조립 완료', onPressed: onComplete),
        ),
      ],
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

class _CompletedScreenState extends State<CompletedScreen> {
  int secondsLeft = 10;

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
                  fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),

              const SizedBox(height: 44),

              KeyringPreview(
                mbti: widget.mbti,
                colors: widget.colors,
                large: true,
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
                        '소지품을 확인하세요. 조립대에 물건을 두고 가지 마세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
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
class WrongWorkstationScreen extends StatelessWidget {
  final String assignedWorkstation;
  final VoidCallback onRetry;
  final VoidCallback onHelp;

  const WrongWorkstationScreen({
    super.key,
    required this.assignedWorkstation,
    required this.onRetry,
    required this.onHelp,
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

              Text(
                '이 QR 코드는 다른 조립대에 배정되어 있습니다.\n'
                '배정된 조립대로 이동한 후 다시 스캔하세요.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                    number: workstationNumber,
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
                    number: assignedWorkstation,
                    backgroundColor: const Color(0xFFD9EFD7),
                    numberColor: Color(0xFF389544),
                  ),
                ],
              ),

              const SizedBox(height: 52),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 360,
                    height: 92,
                    child: PrimaryButton(
                      text: '조립대 $assignedWorkstation로 이동',
                      onPressed: onRetry,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 210,
                    height: 92,
                    child: OutlineButton(text: '도움말', onPressed: onHelp),
                  ),
                ],
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
            fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w600,
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
        SizedBox(height: large ? 18 : 12),
        SizedBox(
          width: keySize * 4 + spacing * 3,
          height: 28,
          child: CustomPaint(painter: KeyringLinePainter()),
        ),
      ],
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
