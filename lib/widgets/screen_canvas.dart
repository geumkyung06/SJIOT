import 'package:flutter/material.dart';

import 'app_top_bar.dart';

/// 모든 화면이 함께 쓰는 고정 디자인 캔버스.
///
/// 기기 화면은 1340 x 800 (실측 190mm x 113mm)이고
/// 위쪽 [AppTopBar.height]만큼은 로고 바가 차지하므로
/// 화면 하나가 쓸 수 있는 영역은 1340 x 725이다.
///
/// 모든 화면을 이 좌표계 위에 그린 뒤 통째로 [FittedBox]로 맞추기 때문에
/// 해상도나 비율이 다른 기기에서도 화면이 잘리거나 스크롤되지 않는다.
class ScreenCanvas extends StatelessWidget {
  /// 기기 해상도
  static const double deviceWidth = 1340;
  static const double deviceHeight = 800;

  /// 로고 바를 뺀 화면 영역 — 모든 화면의 디자인 기준 크기
  static const double width = deviceWidth;
  static const double height = deviceHeight - AppTopBar.height;

  /// 화면에서 가장 큰 글씨 크기 — 모든 화면 공통 상한
  static const double maxFontSize = 80;

  /// 화면에서 가장 작은 글씨 크기 — 모든 화면 공통 하한
  static const double minFontSize = 17;

  /// 기본 여백 — 위쪽은 왼쪽 위 조립대 칩과 겹치지 않을 만큼 띄운다.
  static const EdgeInsets defaultPadding = EdgeInsets.fromLTRB(64, 80, 64, 44);

  final EdgeInsets padding;

  /// 내용이 캔버스보다 커지면 내용만 한 번 더 줄여서 맞춘다.
  /// 가로를 꽉 채우는 [Row]·[Expanded] 구조에서는 false로 둔다.
  final bool shrinkContent;

  final Widget child;

  const ScreenCanvas({
    super.key,
    required this.child,
    this.padding = defaultPadding,
    this.shrinkContent = true,
  });

  /// 세로로 쌓아 가운데 정렬하는 기본 형태의 화면
  factory ScreenCanvas.column({
    Key? key,
    EdgeInsets padding = defaultPadding,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    required List<Widget> children,
  }) {
    return ScreenCanvas(
      key: key,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = shrinkContent
        ? Center(child: FittedBox(fit: BoxFit.scaleDown, child: child))
        : child;

    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: width,
          height: height,
          child: Padding(padding: padding, child: content),
        ),
      ),
    );
  }
}
