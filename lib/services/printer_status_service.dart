// [신규] 영수증 프린터 용지 상태 확인.
//
// Windows 드라이버에게 "지금 이 프린터 용지 있어?"를 직접 물어봐서,
// 출력이 실패하기 '전에' 미리 알아내기 위한 서비스입니다.
// (인쇄를 실제로 시도했다가 실패하는 걸로 판단하는 방식이 아닙니다 — 그렇게
// 하면 이미 한 손님의 주문이 끝난 뒤에야 알게 되어 늦습니다.)
//
// 플랫폼별 분기(조건부 임포트):
// - 웹(Chrome) 빌드 : printer_status_web.dart (항상 "모름"만 반환 — no-op)
// - 그 외(Windows)  : printer_status_io.dart  (win32로 실제 드라이버 조회)
import 'printer_status_web.dart' if (dart.library.io) 'printer_status_io.dart'
    as platform;

/// 영수증 프린터 용지 상태.
enum PaperStatus {
  /// 용지 있음(또는 적어도 "없음"은 아님으로 확인됨).
  ok,

  /// 용지 없음으로 확인됨 — 주문을 막아야 합니다.
  paperOut,

  /// 조회 실패/프린터를 못 찾음/드라이버가 상태를 지원하지 않음 등으로
  /// 판단할 수 없는 상태입니다. 이 경우는 "모름 = 막지 않음"으로 처리해서,
  /// 조회 자체가 잠깐 실패했다고 손님 주문을 막아버리는 일이 없게 합니다.
  unknown,
}

class PrinterStatusService {
  /// [printerName]으로 설치된 프린터(예: "SEWOO SLK-TS100")의 Windows 드라이버
  /// 상태를 조회해서 용지 유무를 돌려줍니다.
  static PaperStatus checkPaperStatus(String printerName) {
    final int code;
    try {
      code = platform.checkPaperStatusCode(printerName);
    } catch (_) {
      return PaperStatus.unknown;
    }

    switch (code) {
      case 0:
        return PaperStatus.ok;
      case 1:
        return PaperStatus.paperOut;
      default:
        return PaperStatus.unknown;
    }
  }
}
