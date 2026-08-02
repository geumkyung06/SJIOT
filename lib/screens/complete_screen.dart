import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// STEP 06 — 제작 중 / 완성 (보드 선택 단계 제외로 07→06)
class CompleteScreen extends StatefulWidget {
  final String boardShape; // '1x4' | '2x2'
  final List<String> letters;
  final Color Function(int index) colorAt;
  final Map<String, dynamic>? orderStatus;
  final VoidCallback onRestart;

  const CompleteScreen({
    super.key,
    required this.boardShape,
    required this.letters,
    required this.colorAt,
    required this.orderStatus,
    required this.onRestart,
  });

  @override
  State<CompleteScreen> createState() => _CompleteScreenState();
}

class _CompleteScreenState extends State<CompleteScreen> with TickerProviderStateMixin {
  int get _stage {
    final status = widget.orderStatus?['status'] as String?;
    if (status == 'done') return 3;
    if (status == 'in_progress') return 2;
    if (status == 'assigned') return 1;
    return 0;
  }

  static const List<double> _stageRobotX = [6, 26, 50, 78];

  int _lastStage = -1;

  late final AnimationController _robotController;
  late Animation<double> _robotX;

  late final AnimationController _armController;

  late final AnimationController _stageBadgeController;

  late final AnimationController _statusPulseController;
  late final Animation<double> _statusPulseOpacity;

  late final AnimationController _titleBounceController;
  late final Animation<double> _titleBounceScale;
  bool _titleBouncePlayed = false;

  late final List<bool> _warehouseRevealed;
  bool _warehouseTriggered = false;

  int _assembledCount = 0;
  bool _assemblyTriggered = false;

  @override
  void initState() {
    super.initState();

    _robotController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _robotX = AlwaysStoppedAnimation(_stageRobotX[0]);

    _armController = AnimationController(vsync: this, duration: const Duration(milliseconds: 850));

    _stageBadgeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))
      ..repeat();

    _statusPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
      ..repeat(reverse: true);
    _statusPulseOpacity = Tween<double>(begin: 1.0, end: 0.35).animate(
      CurvedAnimation(parent: _statusPulseController, curve: Curves.easeInOut),
    );

    _titleBounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _titleBounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _titleBounceController, curve: Curves.easeOut));

    _warehouseRevealed = List.filled(widget.letters.length, false);

    _syncWithStage(initial: true);
  }

  @override
  void didUpdateWidget(covariant CompleteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWithStage(initial: false);
  }

  void _syncWithStage({required bool initial}) {
    final stage = _stage;
    if (stage == _lastStage) return;
    final fromX = initial ? _stageRobotX[0] : _robotX.value;
    _lastStage = stage;

    _robotX = Tween<double>(begin: fromX, end: _stageRobotX[stage]).animate(
      CurvedAnimation(parent: _robotController, curve: Curves.easeInOut),
    );
    _robotController.forward(from: 0);

    if (stage == 2) {
      _armController.repeat();
    } else {
      _armController.stop();
      _armController.value = 0;
    }

    if (stage >= 1 && !_warehouseTriggered) {
      _warehouseTriggered = true;
      for (var i = 0; i < _warehouseRevealed.length; i++) {
        Future.delayed(Duration(milliseconds: i * 100), () {
          if (mounted) setState(() => _warehouseRevealed[i] = true);
        });
      }
    }

    if (stage >= 2 && !_assemblyTriggered) {
      _assemblyTriggered = true;
      for (var i = 0; i < widget.letters.length; i++) {
        Future.delayed(Duration(milliseconds: i * 480), () {
          if (mounted && _assembledCount < i + 1) {
            setState(() => _assembledCount = i + 1);
          }
        });
      }
    }
    if (stage == 3 && _assembledCount < widget.letters.length) {
      _assembledCount = widget.letters.length;
    }

    if (stage == 3 && !_titleBouncePlayed) {
      _titleBouncePlayed = true;
      _titleBounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _robotController.dispose();
    _armController.dispose();
    _stageBadgeController.dispose();
    _statusPulseController.dispose();
    _titleBounceController.dispose();
    super.dispose();
  }

  String _statusText(Map<String, dynamic>? s) {
    if (s == null) return '주문 접수 중...';
    switch (s['status']) {
      case 'waiting':
        return '대기열 ${s['position_in_queue']}번째';
      case 'assigned':
        return '${s['station_id']}번 조립대 배정됨';
      case 'in_progress':
        return '${s['station_id']}번 조립대에서 제작 중';
      default:
        return '상태 확인 중...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.orderStatus?['status'] as String?;
    final isError = status == 'error';
    final isDone = status == 'done';
    final stage = _stage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('STEP 06 / 06', style: AppTextStyles.label),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _titleBounceScale,
          builder: (context, child) => Transform.scale(
            scale: isDone ? _titleBounceScale.value : 1.0,
            child: child,
          ),
          child: Text(isDone ? '완성! 🎉' : '제작 중...', style: AppTextStyles.heading),
        ),
        const SizedBox(height: 24),
        Container(
          width: 580,
          height: 210,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
          child: Stack(
            children: [
              // 진행바
              Align(
                alignment: Alignment.topLeft,
                child: AnimatedFractionallySizedBox(
                  widthFactor: stage / 3,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  child: Container(height: 4, color: AppColors.green),
                ),
              ),

              // 부품창고 (우상단)
              Positioned(
                top: 16,
                right: 20,
                child: _WarehouseRack(
                  letters: widget.letters,
                  colorAt: widget.colorAt,
                  revealed: _warehouseRevealed,
                  boardShape: widget.boardShape,
                ),
              ),

              // 로봇
              AnimatedBuilder(
                animation: _robotX,
                builder: (context, child) {
                  final fraction = (_robotX.value / 100).clamp(0.0, 1.0);
                  return Align(
                    alignment: Alignment(-1 + 2 * fraction, 1),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: child,
                    ),
                  );
                },
                child: _RobotUnit(armController: _armController, stage: stage),
              ),

              // 조립 트레이 (하단 중앙)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: _AssemblyTray(
                  letters: widget.letters,
                  colorAt: widget.colorAt,
                  assembledCount: _assembledCount,
                  boardShape: widget.boardShape,
                ),
              ),
              // (컨베이어 벨트 제거됨 — 배경과 안 어울리는 회색 띠였음)
            ],
          ),
        ),
        const SizedBox(height: 24),
        _StageStepsRow(stage: stage, pulseController: _stageBadgeController),
        const SizedBox(height: 32),
        if (isDone)
          Container(
            width: 420,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(border: Border.all(color: AppColors.green, width: 2)),
            child: const Column(
              children: [
                Text('맞춤 MBTI 키링 완성!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('수령 창구에서 받아가세요', style: AppTextStyles.body),
              ],
            ),
          )
        else if (isError)
          Column(
            children: [
              Text('오류: ${widget.orderStatus?['error'] ?? '알 수 없는 오류'}', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              TextButton(onPressed: widget.onRestart, child: const Text('처음으로')),
            ],
          )
        else
          Column(
            children: [
              AnimatedBuilder(
                animation: _statusPulseOpacity,
                builder: (context, child) => Opacity(opacity: _statusPulseOpacity.value, child: child),
                child: Text(_statusText(widget.orderStatus), style: AppTextStyles.body),
              ),
              const SizedBox(height: 12),
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
      ],
    );
  }
}

class _RobotUnit extends StatelessWidget {
  final AnimationController armController;
  final int stage;
  const _RobotUnit({required this.armController, required this.stage});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.smart_toy, size: 48, color: AppColors.coral),
          Positioned(
            right: -20,
            top: 14,
            child: AnimatedBuilder(
              animation: armController,
              builder: (context, child) {
                final angle = stage == 2
                    ? (armController.value < 0.5
                        ? -45 * (armController.value * 2)
                        : -45 * (2 - armController.value * 2))
                    : 0.0;
                return Transform.rotate(
                  angle: angle * 3.14159265 / 180,
                  alignment: Alignment.centerLeft,
                  child: child,
                );
              },
              child: Container(width: 22, height: 5, decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(3))),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarehouseRack extends StatelessWidget {
  final List<String> letters;
  final Color Function(int index) colorAt;
  final List<bool> revealed;
  final String boardShape;
  const _WarehouseRack({
    required this.letters,
    required this.colorAt,
    required this.revealed,
    required this.boardShape,
  });

  @override
  Widget build(BuildContext context) {
    final is2x2 = boardShape == '2x2';
    Widget tile(int i) => AnimatedScale(
          scale: revealed[i] ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.all(2),
            alignment: Alignment.center,
            color: colorAt(i),
            child: Text(letters[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('부품창고', style: TextStyle(fontSize: 8, color: AppColors.muted, letterSpacing: 1)),
        const SizedBox(height: 4),
        if (is2x2)
          Column(children: [Row(children: [tile(0), tile(1)]), Row(children: [tile(2), tile(3)])])
        else
          Row(children: List.generate(letters.length, tile)),
      ],
    );
  }
}

class _AssemblyTray extends StatelessWidget {
  final List<String> letters;
  final Color Function(int index) colorAt;
  final int assembledCount;
  final String boardShape;
  const _AssemblyTray({
    required this.letters,
    required this.colorAt,
    required this.assembledCount,
    required this.boardShape,
  });

  @override
  Widget build(BuildContext context) {
    final is2x2 = boardShape == '2x2';
    Widget tile(int i) {
      final show = i < assembledCount;
      return AnimatedScale(
        scale: show ? 1 : 0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        child: AnimatedRotation(
          turns: show ? 0 : -12 / 360,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          child: Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.all(2),
            alignment: Alignment.center,
            color: colorAt(i),
            child: Text(letters[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      );
    }

    return Column(
      children: [
        const Text('조립', style: TextStyle(fontSize: 8, color: AppColors.muted, letterSpacing: 1)),
        const SizedBox(height: 4),
        if (is2x2)
          Column(children: [Row(children: [tile(0), tile(1)]), Row(children: [tile(2), tile(3)])])
        else
          Row(children: List.generate(letters.length, tile)),
      ],
    );
  }
}

class _StageStepsRow extends StatelessWidget {
  final int stage;
  final AnimationController pulseController;
  const _StageStepsRow({required this.stage, required this.pulseController});

  static const _labels = ['창고 준비', '재료 수집', '키링 조립', '완성'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_labels.length * 2 - 1, (idx) {
        if (idx.isOdd) {
          final i = idx ~/ 2;
          return Container(width: 32, height: 1, color: stage > i ? AppColors.ink : AppColors.muted, margin: const EdgeInsets.only(bottom: 16));
        }
        final i = idx ~/ 2;
        final isActive = stage == i;
        final isDone = stage > i;
        return Column(
          children: [
            AnimatedBuilder(
              animation: pulseController,
              builder: (context, child) {
                final scale = isActive
                    ? 1.0 + 0.14 * (pulseController.value < 0.5 ? pulseController.value * 2 : 2 - pulseController.value * 2)
                    : 1.0;
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                color: isDone ? AppColors.ink : (isActive ? AppColors.orange : AppColors.tileEmpty),
                child: Text(
                  isDone ? '✓' : '${i + 1}',
                  style: TextStyle(color: isDone || isActive ? Colors.white : AppColors.ink, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(_labels[i], style: const TextStyle(fontSize: 9, color: AppColors.muted)),
          ],
        );
      }),
    );
  }
}