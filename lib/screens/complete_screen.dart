import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CompleteScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final status = orderStatus?['status'] as String?;
    final isError = status == 'error';
    final isDone = status == 'done';
    final warehouseReady = status != null && status != 'waiting';
    final assembling = status == 'in_progress' || isDone;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('STEP 07 / 07', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Text(isDone ? '완성! 🎉' : '제작 중...', style: AppTextStyles.heading),
        const SizedBox(height: 24),
        Container(
          width: 600,
          height: 240,
          decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
          child: Column(
            children: [
              Container(height: 6, color: AppColors.green),
              Expanded(
                child: Stack(
                  children: [
                    const Positioned(left: 40, top: 60, child: Icon(Icons.smart_toy, size: 60, color: AppColors.coral)),
                    Positioned(
                      right: 24,
                      top: 20,
                      child: _TileRow(label: '부품창고', letters: letters, colorAt: colorAt, boardShape: boardShape),
                    ),
                    Positioned(
                      left: 200,
                      top: 70,
                      child: _TileRow(label: '조립', letters: letters, colorAt: colorAt, boardShape: boardShape),
                    ),
                  ],
                ),
              ),
              Container(height: 20, color: AppColors.tileEmpty),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepBadge(label: '창고 준비', done: warehouseReady),
            _Connector(),
            _StepBadge(label: '재료 수집', done: assembling),
            _Connector(),
            _StepBadge(label: '키링 조립', done: isDone),
            _Connector(),
            _StepBadge(label: '완성', done: isDone, showNumber: !isDone, number: 4),
          ],
        ),
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
              Text('오류: ${orderStatus?['error'] ?? '알 수 없는 오류'}', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              TextButton(onPressed: onRestart, child: const Text('처음으로')),
            ],
          )
        else
          Column(
            children: [
              Text(_statusText(orderStatus), style: AppTextStyles.body),
              const SizedBox(height: 12),
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
      ],
    );
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
}

class _Connector extends StatelessWidget {
  const _Connector();
  @override
  Widget build(BuildContext context) => Container(width: 24, height: 1, color: AppColors.muted, margin: const EdgeInsets.symmetric(horizontal: 6));
}

class _StepBadge extends StatelessWidget {
  final String label;
  final bool done;
  final bool showNumber;
  final int number;
  const _StepBadge({required this.label, required this.done, this.showNumber = false, this.number = 0});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          color: AppColors.ink,
          child: Text(
            showNumber ? '$number' : (done ? '✓' : ''),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _TileRow extends StatelessWidget {
  final String label;
  final List<String> letters;
  final Color Function(int index) colorAt;
  final String boardShape; // '1x4' | '2x2'
  const _TileRow({
    required this.label,
    required this.letters,
    required this.colorAt,
    required this.boardShape,
  });

  Widget _tile(int i, double size) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      alignment: Alignment.center,
      color: colorAt(i),
      child: Text(
        letters[i],
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size > 30 ? 14 : 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final is2x2 = boardShape == '2x2';
    final tileSize = is2x2 ? 28.0 : 34.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body),
        const SizedBox(height: 6),
        if (is2x2)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [_tile(0, tileSize), _tile(1, tileSize)]),
              Row(children: [_tile(2, tileSize), _tile(3, tileSize)]),
            ],
          )
        else
          Row(children: List.generate(letters.length, (i) => _tile(i, tileSize))),
      ],
    );
  }
}