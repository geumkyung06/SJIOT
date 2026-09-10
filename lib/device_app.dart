import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'dev/demo_menu.dart';
import 'models/device_step.dart';
import 'models/order_info.dart';
import 'screens/assembling_screen.dart';
import 'screens/authenticated_screen.dart';
import 'screens/completed_screen.dart';
import 'screens/invalid_qr_screen.dart';
import 'screens/no_show_screen.dart';
import 'screens/order_call_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/waiting_screen.dart';
import 'screens/workstation_setup_screen.dart';
import 'screens/wrong_workstation_screen.dart';
import 'services/api_service.dart';
import 'services/kiosk_service.dart';
import 'theme/app_colors.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/exit_password_dialog.dart';
import 'widgets/screen_canvas.dart';
import 'widgets/workstation_header.dart';

class DeviceApp extends StatelessWidget {
  const DeviceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Pretendard',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.text),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '조립대 디바이스 앱',
      // 스타일을 따로 주지 않은 글씨(스낵바 · 팝업 · 기본 버튼)도
      // ScreenCanvas.minFontSize보다 작아지지 않게 한다.
      theme: base.copyWith(textTheme: _minSizedTextTheme(base.textTheme)),
      home: const DeviceRoot(),
    );
  }
}

/// 글씨 크기가 [ScreenCanvas.minFontSize]보다 작은 스타일을 끌어올린다.
TextStyle? _atLeastMinFont(TextStyle? style) {
  if (style == null) return null;

  final double? size = style.fontSize;

  if (size == null || size >= ScreenCanvas.minFontSize) {
    return style;
  }

  return style.copyWith(fontSize: ScreenCanvas.minFontSize);
}

TextTheme _minSizedTextTheme(TextTheme theme) {
  return TextTheme(
    displayLarge: _atLeastMinFont(theme.displayLarge),
    displayMedium: _atLeastMinFont(theme.displayMedium),
    displaySmall: _atLeastMinFont(theme.displaySmall),
    headlineLarge: _atLeastMinFont(theme.headlineLarge),
    headlineMedium: _atLeastMinFont(theme.headlineMedium),
    headlineSmall: _atLeastMinFont(theme.headlineSmall),
    titleLarge: _atLeastMinFont(theme.titleLarge),
    titleMedium: _atLeastMinFont(theme.titleMedium),
    titleSmall: _atLeastMinFont(theme.titleSmall),
    bodyLarge: _atLeastMinFont(theme.bodyLarge),
    bodyMedium: _atLeastMinFont(theme.bodyMedium),
    bodySmall: _atLeastMinFont(theme.bodySmall),
    labelLarge: _atLeastMinFont(theme.labelLarge),
    labelMedium: _atLeastMinFont(theme.labelMedium),
    labelSmall: _atLeastMinFont(theme.labelSmall),
  );
}

class DeviceRoot extends StatefulWidget {
  const DeviceRoot({super.key});

  @override
  State<DeviceRoot> createState() => _DeviceRootState();
}

class _DeviceRootState extends State<DeviceRoot> with WidgetsBindingObserver {
  // 서비스
  final ApiService _api = ApiService();
  final FlutterTts _tts = FlutterTts();

  // 앱 진행 상태
  DeviceStep _currentStep = DeviceStep.workstationSetup;
  String? _workstationNumber; // 앱을 종료하기 전까지 유지되는 조립대 번호
  String? _assignedWorkstationNumber;
  OrderInfo? _order;

  // 대기번호 호출 상태
  int? _orderCallNumber;
  String? _calledOrderId;
  String? _lastSpokenOrderId;

  // 조립대 상태 조회
  Timer? _stationStatusTimer;
  bool _isFetchingStationStatus = false;

  // 주문 호출 재알림 / 노쇼 처리
  //
  // 호출된 뒤 30초마다 음성으로 다시 부르고,
  // 3분 안에 QR 인증이 없으면 노쇼로 보고 주문을 취소한다.
  static const Duration _orderRecallInterval = Duration(seconds: 30);
  static const Duration _noShowTimeout = Duration(minutes: 3);

  Timer? _orderRecallTimer;
  Timer? _noShowTimer;

  // QR 스캐너를 보고 있는 동안에는 음성 재호출을 하지 않는다.
  bool _isQrScannerOpen = false;

  // 노쇼 취소 요청이 중복 실행되는 것을 막는다.
  bool _isHandlingNoShow = false;

  // 관리자 종료 중에는 화면 고정을 다시 걸지 않는다.
  bool _isExiting = false;

  // 주기
  @override
  void initState() {
    super.initState();
    _initTts();

    WidgetsBinding.instance.addObserver(this);

    // 화면이 올라온 뒤에 고정을 건다. (액티비티가 resumed 상태여야 함)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      KioskService.start();
    });
  }

  /// 사용자가 고정을 풀고 나갔다가 돌아온 경우 다시 고정한다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && !_isExiting) {
      KioskService.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _stationStatusTimer?.cancel();
    _stopCallTimers();

    // TTS 음성이 재생 중이면 종료
    _tts.stop();

    super.dispose();
  }

  // 1. 조립대 설정
  void _selectWorkstation(String number) {
    _stopStationStatusPolling();
    _stopCallTimers();

    setState(() {
      _workstationNumber = number;

      // 아직 서버에서 주문을 받기 전
      _orderCallNumber = null;
      _calledOrderId = null;

      _currentStep = DeviceStep.orderCall;
    });

    // 주문 배정 여부 조회 시작
    _startStationStatusPolling();
  }

  // 2. 조립대 주문 조회
  void _startStationStatusPolling() {
    _stationStatusTimer?.cancel();

    // 화면 진입하자마자 한 번 즉시 조회
    _fetchStationStatus();

    // 이후 2초마다 조회
    _stationStatusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;

      if (_currentStep != DeviceStep.orderCall) {
        return;
      }

      _fetchStationStatus();
    });
  }

  void _stopStationStatusPolling() {
    _stationStatusTimer?.cancel();
    _stationStatusTimer = null;
  }

  Future<void> _fetchStationStatus() async {
    if (_isFetchingStationStatus) {
      return;
    }

    if (_workstationNumber == null) {
      return;
    }

    _isFetchingStationStatus = true;

    final int stationId = int.parse(_workstationNumber!);

    try {
      final result = await _api.getStationStatus(stationId: stationId);

      debugPrint('조립대 주문 조회 성공');
      debugPrint('result: $result');

      final String? orderId = result['order_id']?.toString();

      final dynamic rawOrderSeq = result['order_seq'];

      final int? orderSeq = rawOrderSeq is int
          ? rawOrderSeq
          : int.tryParse(rawOrderSeq?.toString() ?? '');

      if (orderId == null || orderSeq == null) {
        debugPrint('order_id 또는 order_seq가 없습니다.');
        return;
      }

      if (!mounted) return;

      // 이미 음성으로 호출했던 주문인지 확인
      final bool shouldSpeak = _lastSpokenOrderId != orderId;

      setState(() {
        _calledOrderId = orderId;
        _orderCallNumber = orderSeq;
      });

      debugPrint('호출 주문 ID: $_calledOrderId');
      debugPrint('화면 표시 주문번호: $_orderCallNumber');

      // 주문을 찾았으므로 더 이상 폴링하지 않음
      _stopStationStatusPolling();

      // 30초 재호출 · 3분 노쇼 타이머 시작
      _startCallTimers();

      // 새로 배정된 주문일 때만 음성 호출
      if (shouldSpeak) {
        _lastSpokenOrderId = orderId;

        await _speakOrderCall(orderNumber: orderSeq, stationId: stationId);
      }
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.statusCode == 400) {
        // 아직 이 조립대에 주문이 없는 정상적인 대기 상태
        debugPrint('조립대 $stationId: 아직 배정된 주문 없음');

        setState(() {
          _calledOrderId = null;
          _orderCallNumber = null;
        });

        return;
      }

      debugPrint('조립대 주문 조회 오류');
      debugPrint('statusCode: ${e.statusCode}');
      debugPrint('body: ${e.body}');
    } catch (e) {
      debugPrint('조립대 주문 조회 중 통신 오류: $e');
    } finally {
      _isFetchingStationStatus = false;
    }
  }

  // 3. 음성 호출
  Future<void> _initTts() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _speakOrderCall({
    required int orderNumber,
    required int stationId,
  }) async {
    final String message =
        '주문번호 $orderNumber번 고객님, '
        '$stationId번 조립대로 와 주세요.';

    debugPrint('========== 음성 호출 ==========');
    debugPrint(message);
    debugPrint('==============================');

    // 이전 음성이 남아 있으면 정지
    await _tts.stop();

    // 주문번호 음성 호출
    await _tts.speak(message);
  }

  // 3-1. 재호출 · 노쇼 타이머
  void _startCallTimers() {
    _stopCallTimers();

    // 30초마다 대기번호 음성 재호출
    _orderRecallTimer = Timer.periodic(_orderRecallInterval, (_) {
      if (!mounted) return;

      // 호출 화면이 아니거나 스캐너를 보고 있으면 재호출하지 않음
      if (_currentStep != DeviceStep.orderCall) return;
      if (_isQrScannerOpen) return;

      final int? orderNumber = _orderCallNumber;
      final String? workstationNumber = _workstationNumber;

      if (orderNumber == null || workstationNumber == null) return;

      debugPrint('30초 경과 → 주문번호 $orderNumber번 재호출');

      _speakOrderCall(
        orderNumber: orderNumber,
        stationId: int.parse(workstationNumber),
      );
    });

    // 3분 안에 QR 인증이 없으면 노쇼 처리
    _noShowTimer = Timer(_noShowTimeout, _handleNoShow);
  }

  void _stopCallTimers() {
    _orderRecallTimer?.cancel();
    _orderRecallTimer = null;

    _noShowTimer?.cancel();
    _noShowTimer = null;
  }

  /// 호출 후 3분 동안 QR 인증이 없으면 주문을 취소하고 조립대를 비운다.
  Future<void> _handleNoShow() async {
    if (_isHandlingNoShow) return;

    _stopCallTimers();

    final String? orderId = _calledOrderId;
    final String? workstationNumber = _workstationNumber;

    if (orderId == null || workstationNumber == null) {
      debugPrint('노쇼 타이머가 끝났지만 호출 중인 주문이 없음');
      return;
    }

    _isHandlingNoShow = true;

    await _tts.stop();

    // 스캐너를 열어둔 채 시간이 지난 경우 스캐너를 먼저 닫는다.
    if (_isQrScannerOpen) {
      _isQrScannerOpen = false;

      if (mounted) {
        Navigator.of(context).pop();
      }
    }

    final int stationId = int.parse(workstationNumber);

    debugPrint('========== 노쇼 처리 ==========');
    debugPrint('order_id: $orderId');
    debugPrint('station_id: $stationId');

    try {
      final result = await _api.cancelStation(
        stationId: stationId,
        orderId: orderId,
      );

      debugPrint('노쇼 취소 API 결과: $result');

      if (!mounted) return;

      _moveTo(DeviceStep.noShow);
    } on ApiException catch (e) {
      debugPrint('노쇼 취소 실패 (${e.statusCode}): ${e.body}');

      if (!mounted) return;

      if (e.statusCode == 404 || e.statusCode == 409) {
        // 이미 다른 경로로 종료·재배정된 주문이므로 조용히 호출 대기로 복귀
        _reset();
      } else {
        _showMessage('주문 취소 처리에 실패했습니다. (${e.statusCode})');

        _moveTo(DeviceStep.noShow);
      }
    } catch (e) {
      debugPrint('노쇼 취소 중 통신 오류: $e');

      if (!mounted) return;

      _showMessage('서버 통신 오류로 주문 취소를 확인하지 못했습니다.');

      _moveTo(DeviceStep.noShow);
    } finally {
      _isHandlingNoShow = false;
    }
  }

  // 4. QR 인증
  Future<void> _openQrScanner() async {
    if (_orderCallNumber == null || _calledOrderId == null) {
      _showMessage('아직 이 조립대에 배정된 주문이 없습니다.');
      return;
    }

    _isQrScannerOpen = true;

    final String? qrValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    _isQrScannerOpen = false;

    if (!mounted) return;

    // 스캐너를 보는 사이 노쇼 처리 등으로 화면이 바뀐 경우
    if (_currentStep != DeviceStep.orderCall) {
      return;
    }

    if (qrValue == null) {
      return;
    }

    final String rawQrValue = qrValue.trim();

    debugPrint('======================================');
    debugPrint('QR 스캔 완료');
    debugPrint('QR 원본: $rawQrValue');

    final String? scannedOrderId = _extractOrderIdFromQr(rawQrValue);

    debugPrint('추출된 order_id: $scannedOrderId');
    debugPrint('======================================');

    if (scannedOrderId == null) {
      _moveTo(DeviceStep.invalidQr);
      return;
    }

    if (_calledOrderId != null && scannedOrderId != _calledOrderId) {
      debugPrint('호출된 주문과 QR 주문 불일치');
      debugPrint('호출 주문: $_calledOrderId');
      debugPrint('스캔 주문: $scannedOrderId');

      _showMessage('현재 호출된 주문번호와 일치하지 않는 QR 코드입니다.');
      return;
    }

    if (_workstationNumber == null) {
      debugPrint('조립대 번호가 설정되지 않음');
      return;
    }

    final int stationId = int.parse(_workstationNumber!);

    try {
      // 새 백엔드 형식
      //
      // POST /station/{station_id}/start
      // body:
      // {
      //   "order_id": "ord_xxxxxxxx"
      // }
      final startResult = await _api.startStation(
        orderId: scannedOrderId,
        stationId: stationId,
      );

      debugPrint('조립 시작 성공');
      debugPrint('startResult: $startResult');

      // START 성공 응답에 주문 정보가 같이 들어옴
      final String responseOrderId =
          startResult['order_id']?.toString() ?? scannedOrderId;

      final String mbti = startResult['keycap']?.toString() ?? '';

      final List<String> colors =
          (startResult['colors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      debugPrint('응답 order_id: $responseOrderId');
      debugPrint('응답 keycap: $mbti');
      debugPrint('응답 board: ${startResult['board']}');
      debugPrint('응답 colors: $colors');
      debugPrint('응답 board: ${startResult['board']}');

      if (!mounted) return;

      // QR 인증에 성공했으므로 재호출·노쇼 타이머 중지
      _stopCallTimers();

      await _tts.stop();

      setState(() {
        _order = OrderInfo(
          orderId: responseOrderId,
          mbti: mbti,
          colors: colors,
          assignedWorkstation: stationId,
        );

        _currentStep = DeviceStep.waiting;
      });
    } on ApiException catch (e) {
      debugPrint('');
      debugPrint('========== START API 오류 ==========');
      debugPrint('HTTP status: ${e.statusCode}');
      debugPrint('raw body: ${e.body}');
      debugPrint('decoded body: ${e.data}');
      debugPrint('===================================');
      debugPrint('');

      if (!mounted) return;

      switch (e.statusCode) {
        case 400:
          debugPrint('400: 아직 조립대에 배정되지 않은 주문');

          _showMessage('아직 조립대에 배정되지 않은 주문입니다.');
          break;

        case 403:
          debugPrint('403: 다른 조립대에 배정된 주문');

          final assignedStationId = e.data?['assigned_station_id'];

          setState(() {
            if (assignedStationId != null) {
              _assignedWorkstationNumber = assignedStationId.toString().padLeft(
                2,
                '0',
              );
            } else {
              _assignedWorkstationNumber = '--';
            }

            _currentStep = DeviceStep.wrongWorkstation;
          });

          break;

        case 404:
          debugPrint('404: 존재하지 않거나 만료된 주문');

          _moveTo(DeviceStep.invalidQr);
          break;

        case 409:
          debugPrint('409: 이미 처리되었거나 현재 조립대 주문이 아님');

          final errorMessage = e.data?['error']?.toString() ?? '이미 처리된 주문입니다.';

          _showMessage(errorMessage);
          break;

        default:
          debugPrint('처리되지 않은 START 오류: ${e.statusCode}');

          _showMessage('QR 인증 중 오류가 발생했습니다. (${e.statusCode})');
      }
    } catch (e) {
      debugPrint('START API 외 오류: $e');

      if (!mounted) return;

      _showMessage('서버 통신 중 오류가 발생했습니다.');
    }
  }

  String? _extractOrderIdFromQr(String qrValue) {
    final value = qrValue.trim();

    if (value.isEmpty) {
      return null;
    }

    // 혹시 QR에 order_id 자체만 들어있는 경우도 허용
    if (value.startsWith('ord_')) {
      return value;
    }

    // 백엔드 QR 형식:
    // https://.../station/ord_xxxxxxxx/start
    final uri = Uri.tryParse(value);

    if (uri == null) {
      return null;
    }

    final segments = uri.pathSegments;

    if (segments.length >= 3 &&
        segments[segments.length - 3] == 'station' &&
        segments.last == 'start') {
      final orderId = segments[segments.length - 2];

      if (orderId.startsWith('ord_')) {
        return orderId;
      }
    }

    return null;
  }

  // 5. 조립 완료
  Future<void> _finishAssembly() async {
    if (_workstationNumber == null) {
      _showMessage('조립대 번호가 설정되지 않았습니다.');
      return;
    }

    final int stationId = int.parse(_workstationNumber!);

    debugPrint('조립 완료 처리 시작');
    debugPrint('station_id: $stationId');

    try {
      final result = await _api.completeStation(
        stationId: stationId,
        orderId: _order!.orderId,
      );

      debugPrint('조립 완료 API 결과: $result');

      if (!mounted) return;

      if (result['ok'] == true) {
        debugPrint('조립 완료 처리 성공');

        _moveTo(DeviceStep.completed);
      } else {
        debugPrint('200 응답이지만 ok != true: $result');

        _showMessage('조립 완료 응답을 확인할 수 없습니다.');
      }
    } on ApiException catch (e) {
      debugPrint('========== COMPLETE API 오류 ==========');
      debugPrint('HTTP status: ${e.statusCode}');
      debugPrint('raw body: ${e.body}');
      debugPrint('decoded body: ${e.data}');
      debugPrint('======================================');

      if (!mounted) return;

      switch (e.statusCode) {
        case 400:
          _showMessage('이 조립대에 진행 중인 주문이 없습니다.');
          break;

        case 409:
          final currentOrderId = e.data?['current_order_id'];

          debugPrint('서버의 현재 order_id: $currentOrderId');

          _showMessage('현재 화면의 주문과 서버의 주문 정보가 일치하지 않습니다.');
          break;

        default:
          _showMessage('조립 완료 처리에 실패했습니다. (${e.statusCode})');
      }
    } catch (e) {
      debugPrint('조립 완료 API 실패: $e');

      if (!mounted) return;

      _showMessage('서버 통신 중 오류가 발생했습니다.');
    }
  }

  // 화면 상태 관리
  void _moveTo(DeviceStep step) {
    setState(() {
      _currentStep = step;
    });
  }

  void _reset() {
    _stopStationStatusPolling();
    _stopCallTimers();

    setState(() {
      _assignedWorkstationNumber = null;

      _orderCallNumber = null;
      _calledOrderId = null;

      _currentStep = DeviceStep.orderCall;
    });

    _startStationStatusPolling();
  }

  // UI 보조
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 상단 왼쪽 로고를 2초 안에 7번 눌렀을 때.
  /// 비밀번호가 맞으면 앱을 종료한다.
  Future<void> _handleExitRequest() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      // 바깥을 눌러도 닫히지 않는다. [취소] 또는 비밀번호 통과로만 닫힘.
      barrierDismissible: false,
      builder: (_) => const ExitPasswordDialog(),
    );

    if (confirmed != true) {
      return;
    }

    debugPrint('관리자 비밀번호 확인 → 화면 고정 해제 후 앱 종료');

    _isExiting = true;

    // 고정을 먼저 풀어야 앱이 정상적으로 내려간다.
    await KioskService.stop();

    await SystemNavigator.pop();
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

  Color _headerStatusColor(DeviceStep step) => switch (step) {
    DeviceStep.assembling => AppColors.yellow,
    DeviceStep.invalidQr ||
    DeviceStep.wrongWorkstation ||
    DeviceStep.noShow => AppColors.pink,
    DeviceStep.workstationSetup => AppColors.border,
    _ => AppColors.green,
  };

  // 빌드
  @override
  Widget build(BuildContext context) {
    Widget screen;

    switch (_currentStep) {
      case DeviceStep.workstationSetup:
        screen = WorkstationSetupScreen(onSelected: _selectWorkstation);
        break;

      case DeviceStep.orderCall:
        screen = OrderCallScreen(
          orderNumber: _orderCallNumber == null
              ? '조립대 ${_workstationNumber ?? '--'}'
              : _orderCallNumber.toString().padLeft(2, '0'),
          onQrScan: _openQrScanner,
        );
        break;

      case DeviceStep.waiting:
        screen = WaitingScreen(
          workstationNumber: _workstationNumber ?? '--',
          onCountdownFinished: () {
            _moveTo(DeviceStep.assembling);
          },
        );
        break;

      case DeviceStep.authenticated:
        screen = AuthenticatedScreen(
          mbti: _order!.mbti,
          colors: _order!.colors,
          onStart: () {
            _moveTo(DeviceStep.assembling);
          },
        );
        break;

      case DeviceStep.assembling:
        screen = AssemblingScreen(
          mbti: _order!.mbti,
          colors: _order!.colors,
          orderNumber: _orderCallNumber?.toString().padLeft(2, '0'),
          onComplete: _finishAssembly,
        );
        break;

      case DeviceStep.completed:
        screen = CompletedScreen(
          mbti: _order!.mbti,
          colors: _order!.colors,
          onRestart: _reset,
        );
        break;

      case DeviceStep.invalidQr:
        screen = InvalidQrScreen(
          onRetry: _reset,
          onCallStaff: _showStaffDialog,
        );
        break;

      case DeviceStep.noShow:
        screen = NoShowScreen(
          orderNumber: _orderCallNumber?.toString().padLeft(2, '0'),
          onAutoReturn: _reset,
          onCallStaff: _showStaffDialog,
        );
        break;

      case DeviceStep.wrongWorkstation:
        screen = WrongWorkstationScreen(
          currentWorkstation: _workstationNumber ?? '--',
          assignedWorkstation: _assignedWorkstationNumber ?? '--',
          onAutoReturn: _reset,
        );
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            /// 모든 화면 위에 항상 표시되는 로고 바
            /// 왼쪽 로고를 2초 안에 7번 누르면 관리자 종료 창이 뜬다.
            AppTopBar(onSecretTap: _handleExitRequest),

            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: screen),

                  if (_currentStep != DeviceStep.workstationSetup &&
                      _workstationNumber != null)
                    Positioned(
                      top: 20,
                      left: 40,
                      child: WorkstationHeader(
                        workstationNumber: _workstationNumber!,
                        statusColor: _headerStatusColor(_currentStep),
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
                      onWrongWorkstation: () =>
                          _moveTo(DeviceStep.wrongWorkstation),
                      onNoShow: () => _moveTo(DeviceStep.noShow),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
