import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/board_select_screen.dart';
import 'screens/keycap_fill_screen.dart';
import 'screens/complete_screen.dart';

void main() {
  runApp(const ClickyKeyringApp());
}

enum AppStep { home, boardSelect, keycapFill, complete }

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

  String? _boardShape; // '1x4' | '2x2'
  int _boardCount = 4;

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

  // 색상 코드 <-> 실제 색상. 백엔드 COLOR_LIST(r,o,y,g,b,p,w) 중 6개 사용.
  // TAB 키로 이 순서대로 순환.
  static const List<String> _colorCycle = ['r', 'o', 'y', 'g', 'b', 'p'];
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _resetLetters() {
    _letters = List.filled(_boardCount, '');
    _colorCodes = List<String?>.filled(_boardCount, null);
    _cursor = 0;
  }

  // 색이 아직 없는 슬롯은 빈 칸(회색)으로 표시
  Color _colorAt(int index) {
    final code = _colorCodes[index];
    return code != null ? _colorMap[code]! : AppColors.tileEmpty;
  }

  // 제출 시점엔 모든 슬롯이 채워져 있어야 하지만, 혹시 몰라 기본값(r) 방어
  String _colorCode(int index) => _colorCodes[index] ?? _colorCycle.first;

  void _cycleColorAt(int index) {
    final current = _colorCodes[index];
    final currentPos = current == null ? -1 : _colorCycle.indexOf(current);
    final next = _colorCycle[(currentPos + 1) % _colorCycle.length];
    setState(() => _colorCodes[index] = next);
  }

  void _goBack() {
    setState(() {
      if (_step == AppStep.boardSelect) {
        _step = AppStep.home;
      } else if (_step == AppStep.keycapFill) {
        _boardShape = null;
        _resetLetters();
        _step = AppStep.boardSelect;
      }
      // complete 단계는 뒤로가기 없음 — 이미 서버에 주문이 전송된 상태라 취소 로직이 없음
    });
  }

  // 물리적 키 위치 기준 매핑 (logicalKey/keyLabel은 한/영 입력 소스에 따라 값이
  // 바뀌어서 한글 입력 상태일 때 글자 입력이 먹통이 될 수 있음 -> physicalKey로 고정)
  static final Map<PhysicalKeyboardKey, String> _keyCharMap = {
    PhysicalKeyboardKey.keyA: 'A', PhysicalKeyboardKey.keyB: 'B', PhysicalKeyboardKey.keyC: 'C',
    PhysicalKeyboardKey.keyD: 'D', PhysicalKeyboardKey.keyE: 'E', PhysicalKeyboardKey.keyF: 'F',
    PhysicalKeyboardKey.keyG: 'G', PhysicalKeyboardKey.keyH: 'H', PhysicalKeyboardKey.keyI: 'I',
    PhysicalKeyboardKey.keyJ: 'J', PhysicalKeyboardKey.keyK: 'K', PhysicalKeyboardKey.keyL: 'L',
    PhysicalKeyboardKey.keyM: 'M', PhysicalKeyboardKey.keyN: 'N', PhysicalKeyboardKey.keyO: 'O',
    PhysicalKeyboardKey.keyP: 'P', PhysicalKeyboardKey.keyQ: 'Q', PhysicalKeyboardKey.keyR: 'R',
    PhysicalKeyboardKey.keyS: 'S', PhysicalKeyboardKey.keyT: 'T', PhysicalKeyboardKey.keyU: 'U',
    PhysicalKeyboardKey.keyV: 'V', PhysicalKeyboardKey.keyW: 'W', PhysicalKeyboardKey.keyX: 'X',
    PhysicalKeyboardKey.keyY: 'Y', PhysicalKeyboardKey.keyZ: 'Z',
    PhysicalKeyboardKey.digit0: '0', PhysicalKeyboardKey.digit1: '1', PhysicalKeyboardKey.digit2: '2',
    PhysicalKeyboardKey.digit3: '3', PhysicalKeyboardKey.digit4: '4', PhysicalKeyboardKey.digit5: '5',
    PhysicalKeyboardKey.digit6: '6', PhysicalKeyboardKey.digit7: '7', PhysicalKeyboardKey.digit8: '8',
    PhysicalKeyboardKey.digit9: '9',
  };

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.physicalKey == PhysicalKeyboardKey.escape &&
        (_step == AppStep.boardSelect || _step == AppStep.keycapFill)) {
      _goBack();
      return;
    }

    switch (_step) {
      case AppStep.home:
        if (event.physicalKey == PhysicalKeyboardKey.enter ||
            event.physicalKey == PhysicalKeyboardKey.numpadEnter) {
          setState(() => _step = AppStep.boardSelect);
        }
        break;

      case AppStep.boardSelect:
        if (event.physicalKey == PhysicalKeyboardKey.digit1) {
          setState(() {
            _boardShape = '1x4';
            _boardCount = 4;
            _resetLetters();
            _step = AppStep.keycapFill;
          });
        } else if (event.physicalKey == PhysicalKeyboardKey.digit2) {
          setState(() {
            _boardShape = '2x2';
            _boardCount = 4;
            _resetLetters();
            _step = AppStep.keycapFill;
          });
        }
        break;

      case AppStep.keycapFill:
        _handleKeycapFillKey(event);
        break;

      case AppStep.complete:
        break; // 완료/진행 화면에서는 키 입력 무시
    }
  }

  void _handleKeycapFillKey(KeyEvent event) {
    final physicalKey = event.physicalKey;

    // 영문/숫자 1글자 입력 (물리 키 위치 기준이라 한/영 전환 상태와 무관하게 동작)
    final letter = _keyCharMap[physicalKey];
    if (letter != null) {
      setState(() {
        _letters[_cursor] = letter;
        _colorCodes[_cursor] ??= _colorCycle.first; // 처음 입력될 때만 기본색 배정
        if (_cursor < _boardCount - 1) _cursor++;
      });
      return;
    }

    if (physicalKey == PhysicalKeyboardKey.tab) {
      _cycleColorAt(_cursor);
      return;
    }

    if (physicalKey == PhysicalKeyboardKey.arrowLeft) {
      setState(() => _cursor = (_cursor - 1).clamp(0, _boardCount - 1));
    } else if (physicalKey == PhysicalKeyboardKey.arrowRight) {
      setState(() => _cursor = (_cursor + 1).clamp(0, _boardCount - 1));
    } else if (physicalKey == PhysicalKeyboardKey.arrowUp && _boardShape == '2x2') {
      setState(() => _cursor = (_cursor - 2).clamp(0, _boardCount - 1));
    } else if (physicalKey == PhysicalKeyboardKey.arrowDown && _boardShape == '2x2') {
      setState(() => _cursor = (_cursor + 2).clamp(0, _boardCount - 1));
    } else if (physicalKey == PhysicalKeyboardKey.backspace) {
      setState(() => _letters[_cursor] = '');
    } else if (physicalKey == PhysicalKeyboardKey.enter ||
        physicalKey == PhysicalKeyboardKey.numpadEnter) {
      if (_letters.every((l) => l.isNotEmpty)) {
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
      case AppStep.boardSelect:
        screen = const BoardSelectScreen();
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
          letters: _letters,
          colorAt: _colorAt,
          orderStatus: _orderStatus,
          onRestart: _restart,
        );
        break;
    }

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
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                        child: Center(child: screen),
                      ),
                    );
                  },
                ),
              ),
              if (_step == AppStep.boardSelect || _step == AppStep.keycapFill)
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
            Text('이전 (ESC)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}