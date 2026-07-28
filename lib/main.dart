import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animations/animations.dart';

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

// 팀장 확정 전 임시 조치: 4구 고정으로 보드 선택 화면을 건너뜁니다.
// board_select_screen.dart 파일과 관련 코드는 그대로 두었고, 이 값만
// true로 되돌리면 원래 흐름(보드 선택 화면 노출)이 복원됩니다.
const bool kBoardSelectEnabled = false;

// [임시] COSS 백엔드 서버 문제로 API 연동을 끊고 프론트 동작(화면 흐름/애니메이션)만
// 확인하기 위한 플래그. 서버 복구되면 이 값을 true로 되돌리면 원래대로
// 실제 API(재고 조회 / 주문 생성 / 상태 폴링)를 호출합니다.
const bool kApiEnabled = false;

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

  // 화면 전환 방향. 1 = 앞으로(오른쪽에서 슬라이드 인),
  // -1 = 뒤로가기(왼쪽에서 슬라이드 인). 피그마의 `d`(direction) 값과 대응됩니다.
  int _direction = 1;

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

  // 키캡 색상 선택 화면 안내 문구
  String? _keycapMessage;

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
  // 완성(done) 후 자동으로 처음 화면으로 돌아가기까지의 대기 시간
  static const Duration _autoRestartAfterDone = Duration(seconds: 8);
  Timer? _doneRestartTimer;

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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
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

    // [임시] API 연동이 꺼져있으면 실제 서버를 호출하지 않고
    // "품절 없음"으로 간주해 즉시 성공 처리합니다. (프론트 동작 확인용)
    if (!kApiEnabled) {
      setState(() {
        _soldOutBoards = {};
        _soldOutKeycaps = {};
        _soldOutSwitches = {};
        _stockLoading = false;
        _stockError = null;
      });
      return true;
    }

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

        _soldOutSwitches = Set<String>.from(
          stock['switch'] ?? const <String>[],
        );

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
  Future<bool> _moveToStep(AppStep nextStep, {VoidCallback? beforeMove}) async {
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

  // 특정 글자와 색상의 품절 여부
  bool _isKeycapColorSoldOut(String letter, String colorCode) {
    return _soldOutKeycaps.contains('${letter}_$colorCode');
  }

  // 현재 커서에 있는 글자의 품절 색상 집합
  Set<String> _soldOutColorsAtCursor() {
    if (_letters.isEmpty || _cursor < 0 || _cursor >= _letters.length) {
      return {};
    }

    final letter = _letters[_cursor];

    return _pastelColorCycle
        .where((color) => _isKeycapColorSoldOut(letter, color))
        .toSet();
  }

  // 현재 글자의 모든 색상이 품절인지 확인하는 함수
  bool _areAllColorsSoldOutAtCursor() {
    return _soldOutColorsAtCursor().length == _pastelColorCycle.length;
  }

  // 현재 선택된 키캡 색상 중 새로 품절된 항목을 해제
  // 반환값: 처음 발견된 품절 키캡의 인덱스
  int? _removeInvalidColorSelections() {
    int? firstInvalidIndex;

    for (int i = 0; i < _colorCodes.length; i++) {
      final selectedColor = _colorCodes[i];

      // 아직 색상을 선택하지 않은 칸은 검사하지 않음
      if (selectedColor == null) continue;

      final letter = _letters[i];
      final stockCode = '${letter}_$selectedColor';

      if (_soldOutKeycaps.contains(stockCode)) {
        _colorCodes[i] = null;
        firstInvalidIndex ??= i;
      }
    }

    return firstInvalidIndex;
  }

  Future<bool> _refreshKeycapStockForCursor() async {
    final success = await _loadSoldOutStock();

    if (!mounted || !success) {
      return false;
    }

    setState(() {
      // 선택한 색상이 재고 조회 중 품절됐다면 해제
      final invalidIndex = _removeInvalidColorSelections();

      if (invalidIndex != null) {
        _cursor = invalidIndex;
        _keycapMessage = '선택한 부품의 재고가 변경되었습니다. 색상을 다시 선택해 주세요.';
        return;
      }

      // 현재 글자의 모든 색상이 품절된 경우
      if (_areAllColorsSoldOutAtCursor()) {
        _keycapMessage = '선택 가능한 색상이 없습니다. 이전 단계로 돌아가 다른 MBTI를 선택해 주세요.';
      } else {
        _keycapMessage = null;
      }
    });

    return true;
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
      _direction = -1; // 뒤로가기는 항상 -1
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
          // 보드 선택 비활성화 시, axisSelect의 이전 화면은 mbtiResult
          if (kBoardSelectEnabled) {
            _boardShape = null;
            _step = AppStep.boardSelect;
          } else {
            _step = AppStep.mbtiResult;
          }
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

    _direction = 1; // 여기서부터 아래는 전부 "앞으로" 이동이므로 미리 표시

    final isEnter =
        event.physicalKey == PhysicalKeyboardKey.enter ||
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
          await _moveToStep(AppStep.mbtiQuiz, beforeMove: _resetQuiz);
        } else if (event.physicalKey == PhysicalKeyboardKey.digit2) {
          await _moveToStep(AppStep.mbtiManual, beforeMove: _resetManual);
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
          setState(() {
            if (kBoardSelectEnabled) {
              _step = AppStep.boardSelect;
            } else {
              _boardShape = '1x4';
              _boardCount = 4;
              _step = AppStep.axisSelect;
            }
          });
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
        await _handleKeycapFillKey(event);
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
      _axis = axes[digit - 1];
      _letters = (_mbtiResult ?? '----').split('');
      _colorCodes = List<String?>.filled(_boardCount, null);
      _cursor = 0;
      _keycapMessage = null;

      _step = AppStep.keycapFill;
    });
    await _refreshKeycapStockForCursor();
  }

  Future<void> _handleKeycapFillKey(KeyEvent event) async {
    // 재고 조회 중에는 중복 입력 방지
    if (_stockLoading) return;

    final physicalKey = event.physicalKey;
    final digit = _digitMap[physicalKey];

    // --------------------------------------------------
    // 1~4 숫자키: 키캡 색상 선택 또는 변경
    // --------------------------------------------------
    if (digit != null) {
      final selectedColor = _pastelColorCycle[digit - 1];

      // 선택 직전 최신 재고 조회
      final success = await _loadSoldOutStock();

      if (!mounted || !success) return;

      final selectedLetter = _letters[_cursor];
      final stockCode = '${selectedLetter}_$selectedColor';

      setState(() {
        // 기존 선택 중 새로 품절된 색상이 있으면 해제
        final invalidIndex = _removeInvalidColorSelections();

        if (invalidIndex != null) {
          _cursor = invalidIndex;
          _keycapMessage = '선택한 부품의 재고가 변경되었습니다. 색상을 다시 선택해 주세요.';
          return;
        }

        // 현재 글자의 모든 색상이 품절
        if (_isLetterSoldOut(selectedLetter)) {
          _keycapMessage = '선택 가능한 색상이 없습니다. 이전 단계로 돌아가 다른 MBTI를 선택해 주세요.';
          return;
        }

        // 사용자가 누른 색상이 품절이면 기존 선택 유지
        // 커서도 다음 칸으로 이동하지 않음
        if (_soldOutKeycaps.contains(stockCode)) {
          _keycapMessage = '$selectedLetter 키캡의 해당 색상은 재고가 없습니다.';
          return;
        }

        // 선택 가능한 색상이므로 저장
        _colorCodes[_cursor] = selectedColor;
        _keycapMessage = null;

        // 마지막 칸이 아닐 때만 다음 칸으로 자동 이동
        if (_cursor < _boardCount - 1) {
          _cursor++;
        }

        // 자동 이동한 글자의 모든 색상이 품절인지 검사
        if (_isLetterSoldOut(_letters[_cursor])) {
          _keycapMessage = '선택 가능한 색상이 없습니다. 이전 단계로 돌아가 다른 MBTI를 선택해 주세요.';
        }
      });

      return;
    }

    // --------------------------------------------------
    // 화살표: 커서 이동 후 해당 글자의 재고를 다시 조회
    // --------------------------------------------------
    int? nextCursor;

    if (physicalKey == PhysicalKeyboardKey.arrowLeft) {
      nextCursor = (_cursor - 1).clamp(0, _boardCount - 1);
    } else if (physicalKey == PhysicalKeyboardKey.arrowRight) {
      nextCursor = (_cursor + 1).clamp(0, _boardCount - 1);
    } else if (physicalKey == PhysicalKeyboardKey.arrowUp &&
        _boardShape == '2x2') {
      nextCursor = (_cursor - 2).clamp(0, _boardCount - 1);
    } else if (physicalKey == PhysicalKeyboardKey.arrowDown &&
        _boardShape == '2x2') {
      nextCursor = (_cursor + 2).clamp(0, _boardCount - 1);
    }

    if (nextCursor != null) {
      // 우선 커서를 이동
      setState(() {
        _cursor = nextCursor!;
        _keycapMessage = null;
      });

      // 이동한 키캡 글자의 최신 재고 확인
      await _refreshKeycapStockForCursor();
      return;
    }

    // --------------------------------------------------
    // Backspace: 현재 칸의 색상 삭제
    // --------------------------------------------------
    if (physicalKey == PhysicalKeyboardKey.backspace) {
      setState(() {
        _colorCodes[_cursor] = null;
        _keycapMessage = '현재 키캡의 색상 선택을 삭제했습니다.';
      });
      return;
    }

    // --------------------------------------------------
    // ENTER: 전체 선택 여부 및 주문 직전 재고 검사
    // --------------------------------------------------
    final isEnter =
        physicalKey == PhysicalKeyboardKey.enter ||
        physicalKey == PhysicalKeyboardKey.numpadEnter;

    if (isEnter) {
      // 색상을 선택하지 않은 첫 번째 칸 찾기
      final firstEmptyIndex = _colorCodes.indexWhere((color) => color == null);

      if (firstEmptyIndex != -1) {
        setState(() {
          _cursor = firstEmptyIndex;
          _keycapMessage = '색을 모두 선택하세요.';
        });

        await _refreshKeycapStockForCursor();
        return;
      }

      // 네 칸을 모두 선택했더라도 주문 직전 최신 재고 재조회
      final success = await _loadSoldOutStock();

      if (!mounted || !success) return;

      int? firstInvalidIndex;

      setState(() {
        firstInvalidIndex = _removeInvalidColorSelections();

        if (firstInvalidIndex != null) {
          _cursor = firstInvalidIndex!;
          _keycapMessage = '선택한 부품의 재고가 변경되었습니다. 색상을 다시 선택해 주세요.';
        }
      });

      // 품절된 선택이 하나라도 있었다면 주문하지 않음
      if (firstInvalidIndex != null) {
        return;
      }

      // 현재 커서의 글자가 모든 색상 품절인지 마지막으로 검사
      if (_isLetterSoldOut(_letters[_cursor])) {
        setState(() {
          _keycapMessage = '선택 가능한 색상이 없습니다. 이전 단계로 돌아가 다른 MBTI를 선택해 주세요.';
        });
        return;
      }

      await _submitOrder();
    }
  }

  Future<void> _submitOrder() async {
    // 주문 생성 직전 마지막 재고 확인
    final success = await _loadSoldOutStock();

    if (!mounted || !success) return;

    int? invalidIndex;

    setState(() {
      invalidIndex = _removeInvalidColorSelections();

      if (invalidIndex != null) {
        _cursor = invalidIndex!;
        _keycapMessage = '선택한 부품의 재고가 변경되었습니다. 색상을 다시 선택해 주세요.';
      }
    });

    // 재고가 변경된 키캡이 있으면 주문 생성 금지
    if (invalidIndex != null) {
      return;
    }

    // 선택하지 않은 색상이 남아 있으면 주문 생성 금지
    final firstEmptyIndex = _colorCodes.indexWhere((color) => color == null);

    if (firstEmptyIndex != -1) {
      setState(() {
        _cursor = firstEmptyIndex;
        _keycapMessage = '색을 모두 선택하세요.';
      });
      return;
    }

    // 모든 검사를 통과한 뒤에만 완료 화면으로 이동
    setState(() {
      _step = AppStep.complete;
      _orderStatus = null;
      _keycapMessage = null;
    });

    _startAutoRestartTimer();

    // [임시] API 연동이 꺼져있으면 실제 서버 대신 로컬에서 가짜 진행 상태를
    // 흘려보내서, 완성 화면(로봇 이동/조립 연출 등) 애니메이션까지
    // 백엔드 없이 확인할 수 있게 합니다.
    if (!kApiEnabled) {
      _mockOrderFlow();
      return;
    }

    try {
      final colors = List.generate(_boardCount, _colorCode);

      final result = await _api.createOrder(
        board: _boardCount,
        keycap: _letters.join(),
        colors: colors,
        axis: _axis,
      );

      if (!mounted) return;

      setState(() {
        _orderId = result['order_id'] as String?;
        _orderStatus = result;
      });

      _pollStatus();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _orderStatus = {'status': 'error', 'error': e.toString()};
      });
    }
  }

  // [임시] 백엔드 없이 completion 화면 애니메이션을 확인하기 위한
  // 가짜 주문 진행 시뮬레이션. 2초 간격으로 waiting → assigned →
  // in_progress → done 상태를 순서대로 흘려보냅니다.
  void _mockOrderFlow() {
    _orderId = 'mock-order-id';

    final mockSteps = <Map<String, dynamic>>[
      {'status': 'waiting', 'position_in_queue': 1},
      {'status': 'assigned', 'station_id': 1},
      {'status': 'in_progress', 'station_id': 1},
      {'status': 'done'},
    ];

    for (var i = 0; i < mockSteps.length; i++) {
      Future.delayed(Duration(seconds: 2 * (i + 1)), () {
        if (!mounted) return;
        setState(() => _orderStatus = mockSteps[i]);
        if (mockSteps[i]['status'] == 'done') {
          _autoRestartTimer?.cancel();
          _scheduleDoneRestart();
        }
      });
    }
  }

  // 완성 상태가 되면 일정 시간 뒤 자동으로 처음 화면으로 복귀
  void _scheduleDoneRestart() {
    _doneRestartTimer?.cancel();
    _doneRestartTimer = Timer(_autoRestartAfterDone, () {
      if (mounted) _restart();
    });
  }

  void _startAutoRestartTimer() {
    _autoRestartTimer?.cancel();
    _autoRestartTimer = Timer(_stuckTimeout, () {
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
          _scheduleDoneRestart();
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
    _doneRestartTimer?.cancel();
    setState(() {
      _direction = -1;
      _step = AppStep.home;
      _boardShape = null;
      _axis = null;
      _mbtiResult = null;
      _keycapMessage = null;
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
    _doneRestartTimer?.cancel();
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
          optionTexts: (q['options'] as List)
              .map((o) => o['text'] as String)
              .toList(),
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
        screen = AxisSelectScreen(soldOutAxes: _soldOutSwitches);
        break;

      case AppStep.keycapFill:
        screen = KeycapFillScreen(
          boardShape: _boardShape ?? '1x4',
          letters: _letters,
          cursor: _cursor,
          colorAt: _colorAt,

          // 현재 선택된 키캡 글자의 품절 색상
          soldOutColors: _soldOutColorsAtCursor(),

          // 화면 하단 안내 문구
          message: _keycapMessage,

          // 재고 조회 중 표시용
          stockLoading: _stockLoading,
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
                          minHeight: constraints.maxHeight - 48,
                        ),
                        // 화면 전환 애니메이션 (슬라이드 + 페이드, 방향 인식)
                        // fillColor: Colors.transparent 로 지정해서 전환 중
                        // Scaffold의 AppColors.background 위에 별도 흰색 판이
                        // 덧씌워지지 않도록 함.
                        child: Center(
                          child: PageTransitionSwitcher(
                            duration: const Duration(milliseconds: 300),
                            reverse: _direction == -1,
                            transitionBuilder:
                                (child, primaryAnimation, secondaryAnimation) {
                                  return SharedAxisTransition(
                                    animation: primaryAnimation,
                                    secondaryAnimation: secondaryAnimation,
                                    transitionType:
                                        SharedAxisTransitionType.horizontal,
                                    fillColor: Colors.transparent,
                                    child: child,
                                  );
                                },
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: screen,
                            ),
                          ),
                        ),
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
            Text(
              '이전 (ESC)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
