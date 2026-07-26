import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/mbti_choice_screen.dart';
import 'screens/mbti_quiz_screen.dart';
import 'screens/mbti_manual_screen.dart';
import 'screens/mbti_result_screen.dart';
import 'screens/board_select_screen.dart';
import 'screens/axis_select_screen.dart';
import 'screens/keycap_fill_screen.dart';
import 'screens/complete_screen.dart';

void main() {
  runApp(const ClickyKeyringApp());
}

enum AppStep {
  home,
  mbtiChoice,
  mbtiQuiz,
  mbtiManual,
  mbtiResult,
  boardSelect,
  axisSelect,
  keycapFill,
  complete,
}

class ClickyKeyringApp extends StatelessWidget {
  const ClickyKeyringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '딸깍 - Clicky Keyring Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final FocusNode _focusNode = FocusNode();
  final ApiService _api = ApiService();

  AppStep _step = AppStep.home;

  // ---------------- MBTI 검사 (4지선다 모드) ----------------
  static const List<Map<String, dynamic>> _mbtiQuestions = [
    {
      'question': '주말에 에너지를 얻는 방법은?',
      'options': [
        {'text': '친구들과 왁자지껄하게 놀기', 'letter': 'E'},
        {'text': '새로운 사람들과 어울리기', 'letter': 'E'},
        {'text': '혼자 조용히 쉬기', 'letter': 'I'},
        {'text': '소수의 친한 친구와 시간 보내기', 'letter': 'I'},
      ],
    },
    {
      'question': '새로운 정보를 받아들일 때 나는?',
      'options': [
        {'text': '전체적인 흐름과 가능성을 먼저 본다', 'letter': 'N'},
        {'text': '떠오르는 아이디어와 상상을 즐긴다', 'letter': 'N'},
        {'text': '구체적인 사실과 세부사항을 본다', 'letter': 'S'},
        {'text': '경험하고 검증된 것을 믿는다', 'letter': 'S'},
      ],
    },
    {
      'question': '결정을 내릴 때 나는?',
      'options': [
        {'text': '사람들의 감정과 관계를 먼저 고려한다', 'letter': 'F'},
        {'text': '공감과 조화를 중요하게 생각한다', 'letter': 'F'},
        {'text': '논리와 원칙을 기준으로 판단한다', 'letter': 'T'},
        {'text': '객관적인 사실에 따라 결정한다', 'letter': 'T'},
      ],
    },
    {
      'question': '일정을 관리할 때 나는?',
      'options': [
        {'text': '미리 계획을 세우고 그대로 실행한다', 'letter': 'J'},
        {'text': '정리하고 마감을 철저히 지킨다', 'letter': 'J'},
        {'text': '즉흥적으로 상황에 맞춰 움직인다', 'letter': 'P'},
        {'text': '유연하게 계획을 바꾸는 걸 좋아한다', 'letter': 'P'},
      ],
    },
  ];
  int _quizIndex = 0;
  List<String?> _quizAnswers = List<String?>.filled(4, null);

  // ---------------- MBTI 직접 입력(수동) 모드 ----------------
  // I/E, N/S, F/T, P/J 순서
  static const List<List<String>> _manualPairs = [
    ['I', 'E'],
    ['N', 'S'],
    ['F', 'T'],
    ['P', 'J'],
  ];
  int _manualIndex = 0;
  List<String?> _manualAnswers = List<String?>.filled(4, null);

  String? _mbtiResult; // 예: 'ISTJ'

  // ---------------- 본판 / 축 ----------------
  String? _boardShape; // '1x4' | '2x2'
  int _boardCount = 4;
  String? _axis; // 'blue' | 'brown' | 'red' | 'black'

  // ---------------- 품절 재고 ----------------

  Set<String> _soldOutBoards = {};
  Set<String> _soldOutKeycaps = {};
  Set<String> _soldOutSwitches = {};

  bool _stockLoading = false;
  String? _stockError;

  // ---------------- 키캡 색상 ----------------
  late List<String> _letters;
  late List<String?> _colorCodes; // 슬롯별 색상 코드. null = 아직 색 없음(빈 칸)
  int _cursor = 0;

  String? _orderId;
  Map<String, dynamic>? _orderStatus;
  bool _polling = false;
  Timer? _autoRestartTimer;

  // Mobius/창고/조립대 콜백이 아직 실제로 연결 안 된 동안의 임시 안전장치.
  // 이 시간 안에 'done'이 안 되면 자동으로 홈 화면으로 돌아감.
  static const Duration _stuckTimeout = Duration(seconds: 25);

  // 색상 코드 <-> 실제 색상. 백엔드 COLOR_LIST(r,o,y,g,b,p,w) 중
  // 파스텔 4색만 사용: 1 초록, 2 노랑, 3 파랑, 4 빨강
  static const List<String> _pastelColorCycle = ['g', 'y', 'b', 'r'];
  static const Map<String, Color> _colorMap = {
    'r': AppColors.coral,
    'o': AppColors.orange,
    'y': AppColors.yellow,
    'g': AppColors.green,
    'b': AppColors.blue,
    'p': AppColors.purple,
  };

  @override
  void initState() {
    super.initState();
    _resetLetters();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _resetLetters() {
    _letters = List.filled(_boardCount, '');
    _colorCodes = List<String?>.filled(_boardCount, null);
    _cursor = 0;
  }

  void _resetQuiz() {
    _quizIndex = 0;
    _quizAnswers = List<String?>.filled(4, null);
  }

  void _resetManual() {
    _manualIndex = 0;
    _manualAnswers = List<String?>.filled(4, null);
  }

  //------------ 재고 조회 함수 -------------
  Future<bool> _loadSoldOutStock() async {
    if (_stockLoading) return false;

    setState(() {
      _stockLoading = true;
      _stockError = null;
    });

    try {
      print('>>> 재고 조회 시작'); // 테스트 시 터미널 확인용
      final stock = await _api.getSoldOutStock();
      print('>>> 재고 조회 성공: $stock'); // 테스트 시 터미널 확인용

      if (!mounted) return false;

      setState(() {
        _soldOutBoards = Set<String>.from(stock['board'] ?? const <String>[]);

        _soldOutKeycaps = Set<String>.from(stock['keycap'] ?? const <String>[]);

        _soldOutSwitches =
            Set<String>.from(stock['switch'] ?? const <String>[]);

        _stockLoading = false;
      });

      return true;
    } catch (e) {
      print('>>> 재고 조회 실패: $e'); // 테스트 시 터미널 확인용

      if (!mounted) return false;

      setState(() {
        _stockLoading = false;
        _stockError = e.toString();
      });

      return false;
    }
  }

  // 재고를 확인 후 화면 변경
  Future<bool> _moveToStep(
    AppStep nextStep, {
    VoidCallback? beforeMove,
  }) async {
    final success = await _loadSoldOutStock();

    if (!mounted || !success) {
      // 재고 조회 실패 시 현재 화면 유지
      return false;
    }

    setState(() {
      beforeMove?.call();
      _step = nextStep;
    });

    // 화면 이동 후 키보드 포커스 다시 요청
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });

    return true;
  }

  // 주문 시작 전 품절 재고 불러오고,
  // 조회 성공 시에만 MBTI 선택 화면으로 넘어가게 하는 함수
  Future<void> _startOrder() async {
    final success = await _loadSoldOutStock();

    if (!mounted) return;

    if (!success) {
      return;
    }

    setState(() {
      _step = AppStep.mbtiChoice;
    });
  }

  // ------------- MBTI 키캡 글자 별 전체 품절 판단 함수 -----------
  bool _isLetterSoldOut(String letter) {
    const colors = ['r', 'g', 'b', 'y'];

    return colors.every(
      (color) => _soldOutKeycaps.contains('${letter}_$color'),
    );
  }

  // ------------- 축 품절 판단 함수 -----------
  bool _isAxisSoldOut(String axis) {
    return _soldOutSwitches.contains(axis);
  }

  // 색이 아직 없는 슬롯은 빈 칸(회색)으로 표시
  Color _colorAt(int index) {
    final code = _colorCodes[index];
    return code != null ? _colorMap[code]! : AppColors.tileEmpty;
  }

  // 제출 시점엔 모든 슬롯이 채워져 있어야 하지만, 혹시 몰라 기본값(g) 방어
  String _colorCode(int index) => _colorCodes[index] ?? _pastelColorCycle.first;

  void _goBack() {
    setState(() {
      switch (_step) {
        case AppStep.mbtiChoice:
          _step = AppStep.home;
          break;
        case AppStep.mbtiQuiz:
          _resetQuiz();
          _step = AppStep.mbtiChoice;
          break;
        case AppStep.mbtiManual:
          _resetManual();
          _step = AppStep.mbtiChoice;
          break;
        case AppStep.mbtiResult:
          _step = AppStep.mbtiChoice;
          break;
        case AppStep.boardSelect:
          _step = AppStep.mbtiResult;
          break;
        case AppStep.axisSelect:
          _boardShape = null;
          _step = AppStep.boardSelect;
          break;
        case AppStep.keycapFill:
          _axis = null;
          _resetLetters();
          _step = AppStep.axisSelect;
          break;
        default:
          break;
      }
    });
  }

  // 물리적 키 위치 기준 매핑 (logicalKey/keyLabel은 한/영 입력 소스에 따라 값이
  // 바뀌어서 한글 입력 상태일 때 글자 입력이 먹통이 될 수 있음 -> physicalKey로 고정)
  static final Map<PhysicalKeyboardKey, String> _keyCharMap = {
    PhysicalKeyboardKey.keyA: 'A',
    PhysicalKeyboardKey.keyB: 'B',
    PhysicalKeyboardKey.keyC: 'C',
    PhysicalKeyboardKey.keyD: 'D',
    PhysicalKeyboardKey.keyE: 'E',
    PhysicalKeyboardKey.keyF: 'F',
    PhysicalKeyboardKey.keyG: 'G',
    PhysicalKeyboardKey.keyH: 'H',
    PhysicalKeyboardKey.keyI: 'I',
    PhysicalKeyboardKey.keyJ: 'J',
    PhysicalKeyboardKey.keyK: 'K',
    PhysicalKeyboardKey.keyL: 'L',
    PhysicalKeyboardKey.keyM: 'M',
    PhysicalKeyboardKey.keyN: 'N',
    PhysicalKeyboardKey.keyO: 'O',
    PhysicalKeyboardKey.keyP: 'P',
    PhysicalKeyboardKey.keyQ: 'Q',
    PhysicalKeyboardKey.keyR: 'R',
    PhysicalKeyboardKey.keyS: 'S',
    PhysicalKeyboardKey.keyT: 'T',
    PhysicalKeyboardKey.keyU: 'U',
    PhysicalKeyboardKey.keyV: 'V',
    PhysicalKeyboardKey.keyW: 'W',
    PhysicalKeyboardKey.keyX: 'X',
    PhysicalKeyboardKey.keyY: 'Y',
    PhysicalKeyboardKey.keyZ: 'Z',
    PhysicalKeyboardKey.digit0: '0',
    PhysicalKeyboardKey.digit1: '1',
    PhysicalKeyboardKey.digit2: '2',
    PhysicalKeyboardKey.digit3: '3',
    PhysicalKeyboardKey.digit4: '4',
    PhysicalKeyboardKey.digit5: '5',
    PhysicalKeyboardKey.digit6: '6',
    PhysicalKeyboardKey.digit7: '7',
    PhysicalKeyboardKey.digit8: '8',
    PhysicalKeyboardKey.digit9: '9',
  };

  // 숫자 1~4 전용 매핑 (선택지/색상/축 선택용)
  static Map<PhysicalKeyboardKey, int> _digitMap = {
    PhysicalKeyboardKey.digit1: 1,
    PhysicalKeyboardKey.digit2: 2,
    PhysicalKeyboardKey.digit3: 3,
    PhysicalKeyboardKey.digit4: 4,
  };

  void _handleKey(KeyEvent event) async {
    if (event is! KeyDownEvent) return;

    const backableSteps = {
      AppStep.mbtiChoice,
      AppStep.mbtiQuiz,
      AppStep.mbtiManual,
      AppStep.mbtiResult,
      AppStep.boardSelect,
      AppStep.axisSelect,
      AppStep.keycapFill,
    };

    if (event.physicalKey == PhysicalKeyboardKey.escape &&
        backableSteps.contains(_step)) {
      _goBack();
      return;
    }

    final isEnter = event.physicalKey == PhysicalKeyboardKey.enter ||
        event.physicalKey == PhysicalKeyboardKey.numpadEnter;

    switch (_step) {
      // case AppStep.home:
      //   if (isEnter) {
      //     setState(() => _step = AppStep.mbtiChoice);
      //   }
      //   break;
      case AppStep.home:
        if (isEnter && !_stockLoading) {
          _startOrder();
        }
        break;
      case AppStep.mbtiChoice:
        if (event.physicalKey == PhysicalKeyboardKey.digit1) {
          await _moveToStep(
            AppStep.mbtiQuiz,
            beforeMove: _resetQuiz,
          );
        } else if (event.physicalKey == PhysicalKeyboardKey.digit2) {
          await _moveToStep(
            AppStep.mbtiManual,
            beforeMove: _resetManual,
          );
        }
        break;

      case AppStep.mbtiQuiz:
        await _handleQuizKey(event);
        break;

      case AppStep.mbtiManual:
        await _handleManualKey(event);
        break;

      case AppStep.mbtiResult:
        if (isEnter) {
          setState(() => _step = AppStep.boardSelect);
        }
        break;

      case AppStep.boardSelect:
        if (event.physicalKey == PhysicalKeyboardKey.digit1) {
          setState(() {
            _boardShape = '1x4';
            _boardCount = 4;
            _step = AppStep.axisSelect;
          });
        } else if (event.physicalKey == PhysicalKeyboardKey.digit2) {
          setState(() {
            _boardShape = '2x2';
            _boardCount = 4;
            _step = AppStep.axisSelect;
          });
        }
        break;

      case AppStep.axisSelect:
        await _handleAxisKey(event);
        break;

      case AppStep.keycapFill:
        _handleKeycapFillKey(event);
        break;

      case AppStep.complete:
        break; // 완료/진행 화면에서는 키 입력 무시
    }
  }

  Future<void> _handleQuizKey(KeyEvent event) async {
    final digit = _digitMap[event.physicalKey];
    if (digit == null) return;

    final options = _mbtiQuestions[_quizIndex]['options'] as List;
    final letter = options[digit - 1]['letter'] as String;

    // 선택한 E/I/N/S/F/T/J/P의 모든 색상이 품절이면 입력 무시
    if (_isLetterSoldOut(letter)) return;

    if (_quizIndex < _mbtiQuestions.length - 1) {
      // 다음 질문으로 넘어가기 전 재고 재조회
      final success = await _loadSoldOutStock();

      if (!mounted || !success) return;

      // 조회 중 재고가 바뀌었을 수 있으므로 다시 검사
      if (_isLetterSoldOut(letter)) return;

      setState(() {
        _quizAnswers[_quizIndex] = letter;
        _quizIndex++;
      });
    } else {
      // 결과 화면으로 넘어가기 전 재고 재조회
      final success = await _loadSoldOutStock();

      if (!mounted || !success) return;

      if (_isLetterSoldOut(letter)) return;

      setState(() {
        _quizAnswers[_quizIndex] = letter;
        _mbtiResult = _quizAnswers.map((e) => e!).join();
        _step = AppStep.mbtiResult;
      });
    }
  }

  Future<void> _handleManualKey(KeyEvent event) async {
    final letter = _keyCharMap[event.physicalKey];
    if (letter == null) return;

    final pair = _manualPairs[_manualIndex];

    // 현재 단계의 글자가 아니면 무시
    if (letter != pair[0] && letter != pair[1]) return;

    // 화면 전환 직전에 최신 재고 확인
    final success = await _loadSoldOutStock();

    if (!mounted || !success) return;

    // 최신 재고 기준으로 다시 품절 확인
    if (_isLetterSoldOut(letter)) return;

    setState(() {
      _manualAnswers[_manualIndex] = letter;

      if (_manualIndex < _manualPairs.length - 1) {
        _manualIndex++;
      } else {
        _mbtiResult = _manualAnswers.map((e) => e!).join();
        _step = AppStep.mbtiResult;
      }
    });
  }

  Future<void> _handleAxisKey(KeyEvent event) async {
    final digit = _digitMap[event.physicalKey];
    if (digit == null) return;

    const axes = ['blue', 'brown', 'red', 'black'];
    final selectedAxis = axes[digit - 1];

    // 화면 이동 직전에 최신 재고 조회
    final success = await _loadSoldOutStock();

    if (!mounted || !success) return;

    // 최신 재고에서 품절된 축이면 입력 무시
    if (_isAxisSoldOut(selectedAxis)) return;

    setState(() {
      _axis = selectedAxis;

      _letters = (_mbtiResult ?? '----').split('');
      _colorCodes = List<String?>.filled(_boardCount, null);
      _cursor = 0;

      _step = AppStep.keycapFill;
    });
  }

  Future<void> _handleKeycapFillKey(KeyEvent event) async {
    final physicalKey = event.physicalKey;

    final digit = _digitMap[physicalKey];
    if (digit != null) {
      final selectedColor = _pastelColorCycle[digit - 1];
      final selectedLetter = _letters[_cursor];
      final stockCode = '${selectedLetter}_$selectedColor';

      // 색상 선택 직전에 최신 재고 확인
      final success = await _loadSoldOutStock();

      if (!mounted || !success) return;

      // 예: I_r이 품절이면 빨간색 선택 무시
      if (_soldOutKeycaps.contains(stockCode)) return;

      setState(() {
        _colorCodes[_cursor] = selectedColor;

        if (_cursor < _boardCount - 1) {
          _cursor++;
        }
      });
      return;
    }

    if (physicalKey == PhysicalKeyboardKey.arrowLeft) {
      setState(() => _cursor = (_cursor - 1).clamp(0, _boardCount - 1));
    } else if (physicalKey == PhysicalKeyboardKey.arrowRight) {
      setState(() => _cursor = (_cursor + 1).clamp(0, _boardCount - 1));
    } else if (physicalKey == PhysicalKeyboardKey.arrowUp &&
        _boardShape == '2x2') {
      setState(() => _cursor = (_cursor - 2).clamp(0, _boardCount - 1));
    } else if (physicalKey == PhysicalKeyboardKey.arrowDown &&
        _boardShape == '2x2') {
      setState(() => _cursor = (_cursor + 2).clamp(0, _boardCount - 1));
    } else if (physicalKey == PhysicalKeyboardKey.backspace) {
      setState(() => _colorCodes[_cursor] = null);
    } else if (physicalKey == PhysicalKeyboardKey.enter ||
        physicalKey == PhysicalKeyboardKey.numpadEnter) {
      if (_colorCodes.every((c) => c != null)) {
        _submitOrder();
      }
    }
  }

  Future<void> _submitOrder() async {
    setState(() {
      _step = AppStep.complete;
      _orderStatus = null;
    });
    _startAutoRestartTimer();
    try {
      final colors = List.generate(_boardCount, _colorCode);
      final result = await _api.createOrder(
        board: _boardCount,
        keycap: _letters.join(),
        colors: colors,
        axis: _axis, // api_service.dart에서 'switch' 키로 전송됨
      );
      if (!mounted) return;
      setState(() {
        _orderId = result['order_id'] as String?;
        _orderStatus = result;
      });
      _pollStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _orderStatus = {'status': 'error', 'error': e.toString()});
    }
  }

  void _startAutoRestartTimer() {
    _autoRestartTimer?.cancel();
    _autoRestartTimer = Timer(_stuckTimeout, () {
      // 콜백(/mobius/callback)이 아직 실제로 안 들어와서 상태가 'done'까지
      // 못 간 경우 -> 무한정 '제작 중...'에 멈춰있지 않도록 홈으로 복귀
      if (mounted && _orderStatus?['status'] != 'done') {
        _restart();
      }
    });
  }

  void _pollStatus() {
    if (_polling || _orderId == null) return;
    _polling = true;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || _orderId == null) return false;
      try {
        final status = await _api.getOrderStatus(_orderId!);
        if (!mounted) return false;
        setState(() => _orderStatus = status);
        if (status['status'] == 'done') {
          _autoRestartTimer?.cancel();
          return false;
        }
        return true;
      } catch (_) {
        return false;
      }
    }).whenComplete(() => _polling = false);
  }

  void _restart() {
    _autoRestartTimer?.cancel();
    setState(() {
      _step = AppStep.home;
      _boardShape = null;
      _axis = null;
      _mbtiResult = null;
      _resetQuiz();
      _resetManual();
      _orderId = null;
      _orderStatus = null;
      _resetLetters();
    });
  }

  @override
  void dispose() {
    _autoRestartTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget screen;
    switch (_step) {
      case AppStep.home:
        screen = const HomeScreen();
        break;

      case AppStep.mbtiChoice:
        screen = const MbtiChoiceScreen();
        break;

      case AppStep.mbtiQuiz:
        final q = _mbtiQuestions[_quizIndex];
        screen = MbtiQuizScreen(
          questionIndex: _quizIndex,
          totalQuestions: _mbtiQuestions.length,
          question: q['question'] as String,
          optionTexts:
              (q['options'] as List).map((o) => o['text'] as String).toList(),
        );
        break;

      case AppStep.mbtiManual:
        final pair = _manualPairs[_manualIndex];

        screen = MbtiManualScreen(
          questionIndex: _manualIndex,
          totalQuestions: _manualPairs.length,
          letterA: pair[0],
          letterB: pair[1],
          letterASoldOut: _isLetterSoldOut(pair[0]),
          letterBSoldOut: _isLetterSoldOut(pair[1]),
        );
        break;

      case AppStep.mbtiResult:
        screen = MbtiResultScreen(mbti: _mbtiResult ?? '----');
        break;

      case AppStep.boardSelect:
        screen = const BoardSelectScreen();
        break;

      case AppStep.axisSelect:
        screen = AxisSelectScreen(
          soldOutAxes: _soldOutSwitches,
        );
        break;

      case AppStep.keycapFill:
        screen = KeycapFillScreen(
          boardShape: _boardShape ?? '1x4',
          letters: _letters,
          cursor: _cursor,
          colorAt: _colorAt,
        );
        break;

      case AppStep.complete:
        screen = CompleteScreen(
          boardShape: _boardShape ?? '1x4',
          letters: _letters,
          colorAt: _colorAt,
          orderStatus: _orderStatus,
          onRestart: _restart,
        );
        break;
    }

    final showBackButton = _step != AppStep.home && _step != AppStep.complete;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 48),
                        child: Center(child: screen),
                      ),
                    );
                  },
                ),
              ),
              if (showBackButton)
                Positioned(
                  top: 16,
                  left: 16,
                  child: SafeArea(child: _BackButton(onTap: _goBack)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 16, color: AppColors.ink),
            SizedBox(width: 6),
            Text('이전 (ESC)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
