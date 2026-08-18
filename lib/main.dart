import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animations/animations.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

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
import 'screens/design_confirm_screen.dart';
import 'screens/receipt_screen.dart';

void main() {
  runApp(const ClickyKeyringApp());
}

// 팀장 확정 전 임시 조치: 4구 고정으로 보드 선택 화면을 건너뜁니다.
// board_select_screen.dart 파일과 관련 코드는 그대로 두었고, 이 값만
// true로 되돌리면 원래 흐름(보드 선택 화면 노출)이 복원됩니다.
const bool kBoardSelectEnabled = false;

// [임시] 팀 회의 결과로 축(스위치) 선택 단계를 건너뛰고 흑축으로 고정합니다.
// axis_select_screen.dart 파일과 관련 코드는 그대로 두었고, 이 값만
// true로 되돌리면 원래 흐름(축 선택 화면 노출)이 복원됩니다.
const bool kAxisSelectEnabled = false;
const String kFixedAxis = 'black';

// [임시] COSS 백엔드 서버 문제로 API 연동을 끊고 프론트 동작(화면 흐름/애니메이션)만
// 확인하기 위한 플래그. 서버 복구되어 true로 되돌림 -> 실제 API
// (재고 조회 / 주문 생성 / 상태 폴링)를 호출합니다.
const bool kApiEnabled = true;

enum AppStep {
  home,
  mbtiChoice,
  mbtiQuiz,
  mbtiManual,
  mbtiResult,
  boardSelect,
  axisSelect,
  keycapFill,
  complete, // [보류] 로봇 조립 애니메이션 — 현재 플로우에서는 사용하지 않음(팀 논의 후 결정). 코드는 보존.
  designConfirm, // [신규] STEP 06 — 완성된 디자인 확인 화면 (Enter=접수 / Esc=초기화 후 STEP01)
  receipt, // [신규] 영수증 화면 (표시 전용, STEP 번호 없음, 8초 후 자동 복귀)
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

  // ---------------- 중복 주문 방지 ----------------
  // "한 번의 주문 시도"마다 하나씩 갖는 idempotency 키.
  // - [주문하기](Enter) 버튼을 누르는 순간 생성
  // - 응답을 못 받아서(타임아웃/네트워크 오류) 자동 재시도할 때는 재사용
  // - 사용자가 뒤로 가거나(Esc) 처음부터 다시 시작하면 다음 시도에서 새로 생성
  String? _orderAttemptId;
  // 주문 요청이 서버에 나가 있는 동안(응답 대기 중) true.
  // true인 동안은 디자인 확인 화면에서 Enter/Esc 입력을 모두 무시해서
  // 중복 클릭으로 같은 주문이 두 번 나가는 것을 막습니다.
  bool _submittingOrder = false;

  // ---------------- 영수증 화면 표시용 값 ----------------
  String? _receiptOrderNumber;
  String? _receiptTime;
  Uint8List? _receiptQrBytes; // GET /order/{order_id}/qr 로 받아온 실제 QR 이미지

  // 영수증에 표시할 축 이름/색상 (axis_select_screen.dart의 표기와 동일하게 유지)
  static const Map<String, String> _axisLabels = {
    'blue': '청축',
    'brown': '갈축',
    'red': '적축',
    'black': '흑축',
  };
  static const Map<String, Color> _axisColors = {
    'blue': Color(0xFF3E7CE0),
    'brown': Color(0xFF9C6B3F),
    'red': Color(0xFFD5473C),
    'black': Color(0xFF2B2B2B),
  };
  // 영수증에 표시할 키캡 색상 이름 (keycap_fill_screen.dart의 범례와 동일)
  static const Map<String, String> _keycapColorLabels = {
    'g': '초록',
    'y': '노랑',
    'b': '파랑',
    'r': '빨강',
  };

  // Mobius/창고/조립대 콜백이 아직 실제로 연결 안 된 동안의 임시 안전장치.
  // 이 시간 안에 'done'이 안 되면 자동으로 홈 화면으로 돌아감.
  static const Duration _stuckTimeout = Duration(seconds: 25);
  // 완성(done) 후 자동으로 처음 화면으로 돌아가기까지의 대기 시간
  static const Duration _autoRestartAfterDone = Duration(seconds: 8);
  Timer? _doneRestartTimer;

  // 색상 코드 <-> 실제 색상. keycap_fill_screen.dart의 범례(KeycapColors)와
  // 동일한 팔레트를 써야 보드판/완성 화면에 칠해지는 색이 범례와 일치합니다.
  static const List<String> _pastelColorCycle = ['g', 'y', 'b', 'r'];
  static const Map<String, Color> _colorMap = {
    'g': KeycapColors.green,
    'y': KeycapColors.yellow,
    'b': KeycapColors.blue,
    'r': KeycapColors.red,
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
          if (kAxisSelectEnabled) {
            _step = AppStep.axisSelect;
          } else if (kBoardSelectEnabled) {
            _boardShape = null;
            _step = AppStep.boardSelect;
          } else {
            // [임시] 축 선택 화면이 꺼져있으므로 바로 mbtiResult로 되돌아감
            _step = AppStep.mbtiResult;
          }
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
          await _selectMbtiChoice(1);
        } else if (event.physicalKey == PhysicalKeyboardKey.digit2) {
          await _selectMbtiChoice(2);
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
          await _proceedFromMbtiResult();
        }
        break;

      case AppStep.boardSelect:
        if (event.physicalKey == PhysicalKeyboardKey.digit1) {
          _boardShape = '1x4';
          _boardCount = 4;
          if (kAxisSelectEnabled) {
            setState(() => _step = AppStep.axisSelect);
          } else {
            await _goToKeycapFillWithAxis(kFixedAxis);
          }
        } else if (event.physicalKey == PhysicalKeyboardKey.digit2) {
          _boardShape = '2x2';
          _boardCount = 4;
          if (kAxisSelectEnabled) {
            setState(() => _step = AppStep.axisSelect);
          } else {
            await _goToKeycapFillWithAxis(kFixedAxis);
          }
        }
        break;

      case AppStep.axisSelect:
        await _handleAxisKey(event);
        break;

      case AppStep.keycapFill:
        await _handleKeycapFillKey(event);
        break;

      case AppStep.designConfirm:
        // 응답을 기다리는 동안에는 Enter/Esc 모두 무시 (중복 클릭 방지)
        if (_submittingOrder) break;
        if (isEnter) {
          await _confirmAndSubmitOrder();
        } else if (event.physicalKey == PhysicalKeyboardKey.escape) {
          _cancelDesignAndReset();
        }
        break;

      case AppStep.receipt:
        break; // 영수증 화면은 표시 전용 — 키 입력 무시

      case AppStep.complete:
        break; // [보류] 현재 플로우에서 쓰지 않음
    }
  }

  // (터치/키보드 공용) MBTI 결과 화면에서 다음으로 진행
  Future<void> _proceedFromMbtiResult() async {
    if (kBoardSelectEnabled) {
      setState(() => _step = AppStep.boardSelect);
    } else {
      _boardShape = '1x4';
      _boardCount = 4;
      if (kAxisSelectEnabled) {
        setState(() => _step = AppStep.axisSelect);
      } else {
        // [임시] 축 선택 화면을 건너뛰고 고정 축(흑축)으로 바로 진행
        await _goToKeycapFillWithAxis(kFixedAxis);
      }
    }
  }

  // (터치/키보드 공용) MBTI 아는지 선택: 1=몰라요(퀴즈), 2=알아요(직접입력)
  Future<void> _selectMbtiChoice(int digit) async {
    if (digit == 1) {
      await _moveToStep(AppStep.mbtiQuiz, beforeMove: _resetQuiz);
    } else if (digit == 2) {
      await _moveToStep(AppStep.mbtiManual, beforeMove: _resetManual);
    }
  }

  Future<void> _handleQuizKey(KeyEvent event) async {
    final digit = _digitMap[event.physicalKey];
    if (digit == null) return;
    await _selectQuizOption(digit);
  }

  // (터치/키보드 공용) 퀴즈 보기 선택
  Future<void> _selectQuizOption(int digit) async {
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
    await _selectManualLetter(letter);
  }

  // (터치/키보드 공용) 직접입력 화면에서 알파벳 하나 선택
  Future<void> _selectManualLetter(String letter) async {
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
    await _selectAxis(digit);
  }

  // (터치/키보드 공용) 축 선택 (kAxisSelectEnabled=true일 때만 화면에 노출됨)
  Future<void> _selectAxis(int digit) async {
    const axes = ['blue', 'brown', 'red', 'black'];
    final selectedAxis = axes[digit - 1];

    // 화면 이동 직전에 최신 재고 조회
    final success = await _loadSoldOutStock();

    if (!mounted || !success) return;

    // 최신 재고에서 품절된 축이면 입력 무시
    if (_isAxisSoldOut(selectedAxis)) return;

    await _goToKeycapFillWithAxis(selectedAxis);
  }

  // 축을 정하고(사용자가 고르거나, kAxisSelectEnabled=false일 때 고정값으로)
  // 키캡 채우기 화면으로 넘어가는 공통 로직.
  Future<void> _goToKeycapFillWithAxis(String axis) async {
    setState(() {
      _axis = axis;
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
      await _selectKeycapColorDigit(digit);
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
      await _selectKeycapCell(nextCursor);
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
      await _trySubmitKeycapFill();
    }
  }

  // (터치/키보드 공용) 커서 위치의 색을 digit(1~4)에 해당하는 색으로 선택.
  Future<void> _selectKeycapColorDigit(int digit) async {
    if (_stockLoading) return;

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
  }

  // (터치 전용) 키캡 칸을 직접 탭했을 때 커서를 그 칸으로 바로 이동.
  // 키보드의 화살표 이동과 달리 원하는 칸으로 한 번에 건너뜁니다.
  Future<void> _selectKeycapCell(int index) async {
    if (_stockLoading) return;

    final clamped = index.clamp(0, _boardCount - 1);

    setState(() {
      _cursor = clamped;
      _keycapMessage = null;
    });

    // 이동한 키캡 글자의 최신 재고 확인
    await _refreshKeycapStockForCursor();
  }

  // (터치/키보드 공용) 키캡 채우기 완료(=ENTER) 시도.
  // 다 채웠으면 디자인 확인 화면으로, 아니면 빈 칸으로 안내합니다.
  Future<void> _trySubmitKeycapFill() async {
    if (_stockLoading) return;

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

    // [수정] 여기서 바로 주문을 보내지 않고, 먼저 디자인 확인 화면으로
    // 이동합니다. 실제 주문 전송은 그 화면에서 Enter를 눌러야만 일어납니다.
    _goToDesignConfirm();
  }

  // 색 선택을 모두 마친 뒤 STEP 06(디자인 확인)으로 이동.
  // 이 시점에는 아직 어떤 정보도 서버로 전송하지 않습니다.
  void _goToDesignConfirm() {
    setState(() {
      _step = AppStep.designConfirm;
      _keycapMessage = null;
    });
  }

  // STEP 06(디자인 확인)에서 Esc를 눌렀을 때: 아무 정보도 전송하지 않고
  // 모든 선택값을 초기화한 뒤 STEP 01(MBTI를 아는지 선택)로 되돌아갑니다.
  void _cancelDesignAndReset() {
    setState(() {
      _direction = -1;
      _step = AppStep.mbtiChoice;
      _boardShape = null;
      _axis = null;
      _mbtiResult = null;
      _keycapMessage = null;
      _resetQuiz();
      _resetManual();
      _orderId = null;
      _orderStatus = null;
      _receiptOrderNumber = null;
      _receiptTime = null;
      _receiptQrBytes = null;
      _orderAttemptId = null; // 뒤로 가는 경우 = 다음 시도는 새 uuid
      _submittingOrder = false;
      _resetLetters();
    });
  }

  // STEP 06(디자인 확인)에서 Enter를 눌렀을 때 호출됩니다.
  // 이 시점에 비로소 실제 주문/제작 정보가 서버로 전송됩니다.
  Future<void> _confirmAndSubmitOrder() async {
    // 이미 응답을 기다리는 중이면 중복 실행 금지 (안전장치. 실제로는
    // _handleKey에서 이미 걸러지지만, 혹시 모를 재진입에 대비)
    if (_submittingOrder) return;

    // 접수 직전 마지막 재고 확인 (디자인 확인 화면에 머무는 동안 재고가
    // 바뀌었을 수 있으므로 다시 확인합니다)
    final success = await _loadSoldOutStock();

    if (!mounted || !success) return;

    int? invalidIndex;

    setState(() {
      invalidIndex = _removeInvalidColorSelections();

      if (invalidIndex != null) {
        _cursor = invalidIndex!;
        _keycapMessage = '선택한 부품의 재고가 변경되었습니다. 색상을 다시 선택해 주세요.';
        _step = AppStep.keycapFill;
      }
    });

    // 재고가 변경된 키캡이 있으면 주문 생성 금지 (키캡 화면으로 돌려보냄)
    if (invalidIndex != null) {
      return;
    }

    // 선택하지 않은 색상이 남아 있으면 주문 생성 금지
    final firstEmptyIndex = _colorCodes.indexWhere((color) => color == null);

    if (firstEmptyIndex != -1) {
      setState(() {
        _cursor = firstEmptyIndex;
        _keycapMessage = '색을 모두 선택하세요.';
        _step = AppStep.keycapFill;
      });
      return;
    }

    // [주문하기(Enter)를 누른 순간] 이번 "한 번의 주문 시도"에 쓸 idempotency
    // 키를 확보합니다. 이미 값이 있다면(=응답을 못 받아 자동 재시도하는 상황)
    // 그 값을 그대로 재사용하고, 없으면(=새 시도) 새로 만듭니다.
    final attemptId = _orderAttemptId ??= const Uuid().v4();

    setState(() {
      _submittingOrder = true; // Enter를 다시 눌러도 무시되도록 잠금
      _orderId = null;
      _orderStatus = null;
      _receiptOrderNumber = null;
      _receiptTime = _formatNowHHmm();
      _receiptQrBytes = null;
    });

    // [임시] API 연동이 꺼져있으면 실제 서버 대신 로컬에서 가짜 진행 상태를
    // 흘려보내서, 영수증 화면까지 백엔드 없이 확인할 수 있게 합니다.
    if (!kApiEnabled) {
      _orderAttemptId = null; // 이 시도는 여기서 끝남
      setState(() => _submittingOrder = false);
      _mockSubmitAndGoToReceipt();
      return;
    }

    const maxAttempts = 3;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final colors = List.generate(_boardCount, _colorCode);

        final result = await _api.createOrder(
          board: _boardCount,
          keycap: _letters.join(),
          colors: colors,
          axis: _axis,
          idempotencyKey: attemptId,
        );

        if (!mounted) return;

        // 성공했으므로 이 "시도"는 끝. 다음 주문은 새 uuid를 씀.
        _orderAttemptId = null;

        setState(() {
          _submittingOrder = false;
          _orderId = result['order_id'] as String?;
          _orderStatus = result;
          _receiptOrderNumber = _formatOrderNumber(result);
          _step = AppStep.receipt;
        });

        // 영수증 화면 진입 직후부터 8초 뒤 자동으로 처음 화면으로 복귀
        _scheduleDoneRestart();

        // 조립대 배정 상태를 계속 조회해서 "배정 조립대" 박스 문구를
        // complete_screen.dart와 같은 방식(대기열 N번째 → N번 조립대로
        // 이동해주세요 → 제작 중 → 완료)으로 실시간 갱신합니다.
        _pollStatus();

        // 주문이 정상 생성됐으면 그 order_id로 실제 QR 이미지를 받아옵니다.
        // (실패해도 영수증 자체는 이미 떠 있으므로 조용히 자리표시자로 남겨둠)
        final orderId = _orderId;
        if (orderId != null) {
          try {
            final qrBytes = await _api.getOrderQr(orderId);
            if (mounted) {
              setState(() => _receiptQrBytes = qrBytes);
            }
          } catch (e) {
            print('>>> QR 조회 실패: $e');
          }
        }

        return; // 성공했으므로 재시도 루프 종료
      } on TimeoutException {
        // "응답을 못 받은" 경우 → 같은 idempotency 키로 자동 재시도
        print('>>> [주문] 응답 없음(타임아웃) — 재시도 $attempt/$maxAttempts');
        if (attempt == maxAttempts) {
          if (!mounted) return;
          setState(() {
            _submittingOrder = false;
            _step = AppStep.keycapFill;
            _keycapMessage = '서버 응답이 없습니다. 네트워크 상태를 확인하고 다시 시도해 주세요.';
          });
          return;
        }
        // 짧게 대기 후 같은 attemptId로 재시도 (루프의 다음 반복)
        await Future.delayed(const Duration(seconds: 1));
        continue;
      } on http.ClientException {
        // 이것도 "응답을 못 받은" 경우(연결 자체가 안 된 경우)이므로 동일하게 재시도
        print('>>> [주문] 네트워크 연결 실패 — 재시도 $attempt/$maxAttempts');
        if (attempt == maxAttempts) {
          if (!mounted) return;
          setState(() {
            _submittingOrder = false;
            _step = AppStep.keycapFill;
            _keycapMessage = '네트워크 연결에 실패했습니다. 연결 상태를 확인하고 다시 시도해 주세요.';
          });
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
        continue;
      } catch (e) {
        // 서버가 실제로 응답을 준 경우(예: 4xx/5xx, "대기열이 가득 찼습니다" 등).
        // 이건 "응답을 못 받은" 상황이 아니라 결과가 확정된 것이므로 재시도하지 않습니다.
        if (!mounted) return;

        final message = e.toString();
        final isQueueFull = message.contains('대기열이 가득');

        // 이 시도는 결과가 확정되며 끝났으므로 idempotency 키를 버립니다.
        _orderAttemptId = null;

        if (isQueueFull) {
          setState(() {
            _submittingOrder = false;
            _receiptOrderNumber = null;
            _receiptQrBytes = null; // 실제 주문이 생성되지 않았으므로 QR도 없음
            _step = AppStep.receipt;
          });
          _scheduleDoneRestart();
        } else {
          // 그 외의 오류는 키캡 화면으로 돌려보내고 안내 문구로 표시합니다.
          setState(() {
            _submittingOrder = false;
            _step = AppStep.keycapFill;
            _keycapMessage = '주문 처리 중 오류가 발생했습니다. 다시 시도해 주세요.';
          });
        }
        return;
      }
    }
  }

  // [임시] API 연동이 꺼져있을 때, 접수 → 영수증까지의 흐름을 백엔드 없이
  // 확인할 수 있도록 하는 가짜 처리.
  void _mockSubmitAndGoToReceipt() {
    _orderId = 'mock-order-id';
    setState(() {
      _receiptOrderNumber = (DateTime.now().millisecondsSinceEpoch % 900 + 100).toString();
      _orderStatus = {'status': 'waiting', 'position_in_queue': 1};
      _receiptQrBytes = null; // 목업 모드에서는 실제 QR 이미지가 없음(자리표시자로 표시)
      _step = AppStep.receipt;
    });
    _scheduleDoneRestart();

    // [임시] 실제 서버 폴링 대신, 2초 간격으로 waiting → assigned →
    // in_progress → done 상태를 흘려보내서 영수증 박스 애니메이션까지
    // 백엔드 없이 확인할 수 있게 합니다.
    final mockSteps = <Map<String, dynamic>>[
      {'status': 'waiting', 'position_in_queue': 1},
      {'status': 'assigned', 'station_id': 1},
      {'status': 'in_progress', 'station_id': 1},
      {'status': 'done', 'station_id': 1},
    ];
    for (var i = 0; i < mockSteps.length; i++) {
      Future.delayed(Duration(seconds: 2 * (i + 1)), () {
        if (!mounted || _step != AppStep.receipt) return;
        setState(() => _orderStatus = mockSteps[i]);
      });
    }
  }

  String _formatNowHHmm() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // 백엔드가 order_status 응답에 "order_seq"(몇 번째 주문인지)를 함께 내려주면
  // 그 값을 그대로 영수증 주문번호로 사용합니다. 혹시 order_seq가 없는
  // 응답이 오는 예외 상황을 대비해 order_id 기반 대체값도 남겨둡니다.
  String _formatOrderNumber(Map<String, dynamic> result) {
    final seq = result['order_seq'];
    if (seq != null) {
      return seq.toString().padLeft(3, '0');
    }

    final orderId = result['order_id'];
    if (orderId == null) return '-';
    final str = orderId.toString();
    if (str.length > 3) return str.substring(str.length - 3).toUpperCase();
    return str;
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
        // [수정] 영수증 화면의 8초 자동 복귀 타이머는 화면 진입 시 이미
        // 예약되어 있으므로 여기서 다시 예약하지 않습니다. (다시 예약하면
        // 화면에 보이는 카운트다운과 실제 복귀 시점이 어긋납니다)
        if (status['status'] == 'done') {
          return false;
        }
        return true;
      } catch (_) {
        return false;
      }
    }).whenComplete(() => _polling = false);
  }

  // 영수증 화면의 "배정 조립대" 박스에 표시할 큰 문구.
  // complete_screen.dart의 _statusText()와 같은 문구 방식을 따릅니다.
  String _receiptStatusHeadline() {
    // 대기열/조립대가 가득 차서 주문 자체가 생성되지 못한 경우
    if (_orderId == null) return '대기 중';

    final status = _orderStatus?['status'] as String?;
    switch (status) {
      case 'waiting':
        final pos = _orderStatus?['position_in_queue'];
        return pos != null ? '대기열 $pos번째' : '대기 중';
      case 'assigned':
        final st = _orderStatus?['station_id'];
        return st != null ? '$st번 조립대로 이동해주세요' : '조립대 배정됨';
      case 'in_progress':
        final st = _orderStatus?['station_id'];
        return st != null ? '$st번 조립대에서 제작 중' : '제작 중';
      case 'done':
        return '제작 완료!';
      default:
        return '접수 처리 중...';
    }
  }

  // 큰 문구 아래에 덧붙일 작은 보조 문구 (필요한 경우에만)
  String? _receiptStatusCaption() {
    if (_orderId == null) return '스태프가 안내해 드립니다';
    return null;
  }

  // 박스 배경색 결정: 실제로 조립대가 움직이고 있는 상태(배정/제작/완료)면
  // 진한 검정, 그 외(대기/접수 처리 중/미배정)에는 옅은 갈색으로 표시합니다.
  bool _receiptStatusIsActive() {
    if (_orderId == null) return false;
    final status = _orderStatus?['status'] as String?;
    return status == 'assigned' || status == 'in_progress' || status == 'done';
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
      _receiptOrderNumber = null;
      _receiptTime = null;
      _receiptQrBytes = null;
      _orderAttemptId = null;
      _submittingOrder = false;
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
        screen = HomeScreen(
          onEnter: () => _startOrder(),
          enabled: !_stockLoading,
        );
        break;

      case AppStep.mbtiChoice:
        screen = MbtiChoiceScreen(onSelect: (digit) => _selectMbtiChoice(digit));
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
          onSelect: (digit) => _selectQuizOption(digit),
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
          onSelect: (letter) => _selectManualLetter(letter),
        );
        break;

      case AppStep.mbtiResult:
        screen = MbtiResultScreen(
          mbti: _mbtiResult ?? '----',
          onNext: () => _proceedFromMbtiResult(),
        );
        break;

      case AppStep.boardSelect:
        screen = const BoardSelectScreen();
        break;

      case AppStep.axisSelect:
        screen = AxisSelectScreen(
          soldOutAxes: _soldOutSwitches,
          onSelect: (digit) => _selectAxis(digit),
        );
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

          // 터치 지원
          onCellTap: (index) => _selectKeycapCell(index),
          onColorTap: (digit) => _selectKeycapColorDigit(digit),
          onSubmit: () => _trySubmitKeycapFill(),
        );
        break;

      case AppStep.complete:
        // [보류] 로봇 조립 애니메이션 — 현재 플로우에서는 진입하지 않지만
        // 코드는 그대로 보존합니다. (팀 논의 후 사용 여부 결정)
        screen = CompleteScreen(
          boardShape: _boardShape ?? '1x4',
          letters: _letters,
          colorAt: _colorAt,
          orderStatus: _orderStatus,
          onRestart: _restart,
        );
        break;

      case AppStep.designConfirm:
        screen = DesignConfirmScreen(
          boardShape: _boardShape ?? '1x4',
          letters: _letters,
          colorAt: _colorAt,
          axisLabel: _axisLabels[_axis] ?? '-',
          axisColor: _axisColors[_axis] ?? AppColors.ink,
          isSubmitting: _submittingOrder,
          onConfirm: () => _confirmAndSubmitOrder(),
          onCancel: _cancelDesignAndReset,
        );
        break;

      case AppStep.receipt:
        screen = ReceiptScreen(
          orderNumber: _receiptOrderNumber ?? '-',
          time: _receiptTime ?? _formatNowHHmm(),
          mbti: _mbtiResult ?? '----',
          axisLabel: _axisLabels[_axis] ?? '-',
          axisColor: _axisColors[_axis] ?? AppColors.ink,
          keycapColors: List.generate(_boardCount, (i) => _colorAt(i)),
          keycapLabels: List.generate(
            _boardCount,
            (i) => _keycapColorLabels[_colorCodes[i]] ?? '-',
          ),
          statusHeadline: _receiptStatusHeadline(),
          statusCaption: _receiptStatusCaption(),
          isActive: _receiptStatusIsActive(),
          qrBytes: _receiptQrBytes,
        );
        break;
    }

    final showBackButton = _step != AppStep.home &&
        _step != AppStep.complete &&
        _step != AppStep.designConfirm &&
        _step != AppStep.receipt;

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
