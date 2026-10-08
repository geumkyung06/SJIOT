// [신규] printer_status_service.dart의 Windows(데스크톱) 빌드용 실제 구현.
//
// win32 패키지(FFI)로 Windows 프린터 드라이버에 직접 상태를 물어봅니다.
// 사용하는 API: OpenPrinter -> GetPrinter(level 2, PRINTER_INFO_2) -> ClosePrinter
// PRINTER_INFO_2.Status 필드의 PRINTER_STATUS_PAPER_OUT(0x10) 비트를 봅니다.
//
// ⚠️⚠️ 아직 실제 기기(SEWOO SLK-TS100)로 검증되지 않았습니다 ⚠️⚠️
// 이 드라이버가 용지 없음 상태를 실제로 PRINTER_STATUS_PAPER_OUT 비트에
// 채워주는지는 Windows 드라이버마다 다를 수 있어서, 반드시 실제 기기에서
// 용지를 뽑아본 뒤 이 함수가 1(용지 없음)을 돌려주는지 확인해야 합니다.
// 만약 계속 2(모름)만 나온다면, 이 드라이버가 이 비트를 지원하지 않는
// 것이므로 다른 방식(예: 인쇄 시도 실패로 판단)으로 바꿔야 합니다 — 이 경우
// 결과를 알려주시면 바로 대응하겠습니다.
//
// 반환값: 0 = 용지 있음, 1 = 용지 없음(확인됨), 2 = 모름(조회 실패 등)
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

int checkPaperStatusCode(String printerName) {
  final namePtr = printerName.toNativeUtf16();
  final phPrinter = calloc<IntPtr>();
  final pcbNeeded = calloc<Uint32>();
  Pointer<Uint8>? buffer;

  try {
    final opened = OpenPrinter(namePtr, phPrinter, nullptr);
    if (opened == 0) {
      // 이름이 다르거나(예: 드라이버 재설치로 이름이 바뀜) 프린터를 열지
      // 못했습니다 — 모름.
      return 2;
    }

    final hPrinter = phPrinter.value;

    try {
      // 1차 호출: 버퍼 크기가 부족하다고 실패하는 게 정상입니다.
      // 이 호출로 필요한 버퍼 크기(pcbNeeded)만 알아냅니다.
      GetPrinter(hPrinter, 2, nullptr, 0, pcbNeeded);
      final needed = pcbNeeded.value;
      if (needed == 0) {
        return 2;
      }

      buffer = calloc<Uint8>(needed);

      final ok = GetPrinter(hPrinter, 2, buffer, needed, pcbNeeded);
      if (ok == 0) {
        return 2;
      }

      final info = buffer.cast<PRINTER_INFO_2>().ref;
      const paperOutBit = 0x10; // PRINTER_STATUS_PAPER_OUT

      if ((info.Status & paperOutBit) != 0) {
        return 1;
      }
      return 0;
    } finally {
      ClosePrinter(hPrinter);
    }
  } catch (_) {
    // FFI 호출 중 예상 못 한 오류 — 주문을 막지 않기 위해 모름으로 처리.
    return 2;
  } finally {
    calloc.free(namePtr);
    calloc.free(phPrinter);
    calloc.free(pcbNeeded);
    if (buffer != null) {
      calloc.free(buffer);
    }
  }
}
