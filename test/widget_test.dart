// 이 프로젝트의 기본 Flutter 위젯 테스트입니다.
//
// [수정] 원래 Flutter 템플릿이 만들어주는 "카운터 앱" 테스트가 그대로
// 남아있어서, 존재하지 않는 'MyApp' 클래스를 찾는 바람에 analyze 에러가
// 나고 있었습니다. 이 프로젝트의 실제 루트 위젯은 main.dart의
// ClickyKeyringApp이고, 애초에 카운터(+ 버튼, 숫자 증가) 기능 자체가
// 없는 앱이라 기존 테스트 내용도 더는 맞지 않았습니다.
//
// 그래서 "앱이 에러 없이 시작 화면을 띄우는지"만 확인하는 간단한 스모크
// 테스트로 바꿨습니다.
//
// [주의] 시작 화면이 뜨면 대기열/영수증 용지 상태를 주기적으로 조회하는
// 타이머가 곧바로 돌기 시작합니다(main.dart의 _startQueuePolling /
// _startPaperPolling). 이 테스트는 그 타이머가 한 번도 울리기 전(=시간을
// 따로 흘려보내지 않은) 첫 프레임만 확인해서, 테스트 중에 실제 네트워크
// 요청과 엮여 불안정해지거나 멈추는 일이 없도록 했습니다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clicky_keyring/main.dart';

void main() {
  testWidgets('앱이 에러 없이 시작 화면을 보여주는지 확인', (WidgetTester tester) async {
    await tester.pumpWidget(const ClickyKeyringApp());
    await tester.pump();

    // 시작 화면의 "시작하기" 버튼은 인트로 애니메이션 때문에 처음엔
    // 투명하더라도 위젯 트리에는 이미 존재해야 합니다 — 즉 앱이 에러 없이
    // 첫 화면까지 정상적으로 그려졌다는 뜻입니다.
    expect(find.text('시작하기'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 폴링 타이머가 테스트 종료 뒤까지 남아있지 않도록 위젯을 명시적으로
    // 해제합니다(ClickyKeyringApp이 사라지면 main.dart의 dispose()가
    // 타이머들을 정리합니다).
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
