import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPrinterService {
  // SLK-TS100 = 80mm 영수증 프린터.
  // [수정] 이 PC의 Windows 드라이버(SEWOO SLK-TS100)가 제공하는 용지는 폭
  // 72mm(72×210, 72×297, 72×3297)뿐이고 기본 용지도 72×210입니다. 예전에는
  // 80×180mm로 인쇄를 요청해서 드라이버가 지원하지 않는 크기였기 때문에,
  // 기본 크기를 드라이버 기본 용지(72×210)에 맞춥니다.
  // (실제 인쇄에서는 아래 _fitToPrinter가 프린터가 알려준 실제 용지 크기를
  // 우선 사용하고, 이 값은 프린터가 크기를 알려주지 않을 때의 대비용입니다.)
  static final PdfPageFormat _receiptFormat = PdfPageFormat(
    72 * PdfPageFormat.mm,
    210 * PdfPageFormat.mm,
    marginAll: 4 * PdfPageFormat.mm,
  );

  /// [프린터 점검용] 마지막 출력 때 프린터가 알려준 정보(이름/사용 가능 여부/
  /// 실제 용지 크기). main.dart의 화면 우측 상단 점검 표시에 보여줍니다.
  static String? lastPrintInfo;

  /// 프린터가 알려준 실제 용지 크기에 맞춰 PDF 페이지 크기를 정합니다.
  /// 값이 이상하면(예: 3297mm 롤 길이) 종이가 한없이 나오지 않도록
  /// 기본 크기로 되돌립니다.
  static PdfPageFormat _fitToPrinter(PdfPageFormat reported) {
    const mm = PdfPageFormat.mm;
    final width =
        (reported.width >= 40 * mm && reported.width <= 90 * mm)
            ? reported.width
            : _receiptFormat.width;
    final height =
        (reported.height >= 100 * mm && reported.height <= 300 * mm)
            ? reported.height
            : _receiptFormat.height;
    return PdfPageFormat(width, height, marginAll: 4 * mm);
  }

  /// 프린터 이름이 우리가 찾는 영수증 프린터(SLK-TS100/SEWOO)인지 확인합니다.
  static bool _isTargetPrinterName(String name) {
    final lower = name.toLowerCase();
    return lower.contains('slk-ts100') ||
        lower.contains('slk ts100') ||
        lower.contains('sewoo');
  }

  /// [신규] 설치된 프린터 목록에서 영수증 프린터(SLK-TS100)를 찾습니다.
  /// 실제 출력(printReceipt)과, 출력 전 용지 상태만 미리 확인하고 싶을 때
  /// (printer_status_service.dart) 둘 다 이 메서드로 같은 탐색 로직을 씁니다.
  /// 못 찾으면 예외를 던지지 않고 null을 돌려줍니다 — 호출하는 쪽에서
  /// "프린터가 없으면 그냥 모름"처럼 각자 사정에 맞게 처리하도록 하기 위함입니다.
  static Future<Printer?> findTargetPrinter() async {
    final printers = await Printing.listPrinters();

    debugPrint('========== 설치된 프린터 ==========');

    for (final printer in printers) {
      debugPrint(
        '프린터: ${printer.name} '
        '/ available=${printer.isAvailable} '
        '/ default=${printer.isDefault}',
      );
    }

    debugPrint('===================================');

    for (final printer in printers) {
      if (_isTargetPrinterName(printer.name)) {
        return printer;
      }
    }

    return null;
  }

  /// 실제 SLK-TS100으로 영수증 출력
  static Future<void> printReceipt({
    required String orderNumber,
    required String time,
    required String mbti,
    required List<String> keycapLabels,
    Uint8List? qrBytes,
  }) async {
    lastPrintInfo = null;

    // 1~2. 설치된 프린터 목록에서 SLK-TS100 찾기 (findTargetPrinter 안에서
    // 콘솔에 설치된 프린터 전체 목록도 같이 찍습니다)
    final targetPrinter = await findTargetPrinter();

    if (targetPrinter == null) {
      throw Exception(
        'SLK-TS100 프린터를 찾을 수 없습니다. '
        'Windows 프린터 설정에서 먼저 프린터가 설치되어 있는지 확인해주세요.',
      );
    }

    debugPrint('선택된 프린터: ${targetPrinter.name}');

    // 3~4. 프린터가 알려준 실제 용지 크기로 영수증 PDF를 만들어 바로 출력
    // [수정] usePrinterSettings: true — 요청한 임의 크기(예전 80×180mm)를
    // 드라이버에 강제로 넘기지 않고, 테스트 페이지와 같은 드라이버 기본 설정
    // (기본 용지 72×210)으로 출력합니다. PDF는 프린터가 onLayout으로 알려준
    // 실제 용지 크기에 맞춰 그 자리에서 만듭니다.
    PdfPageFormat? reportedFormat;

    final result = await Printing.directPrintPdf(
      printer: targetPrinter,
      name: 'receipt_$orderNumber',
      format: _receiptFormat,
      dynamicLayout: false,
      usePrinterSettings: true,
      onLayout: (format) async {
        reportedFormat = format;
        return _buildReceiptPdf(
          orderNumber: orderNumber,
          time: time,
          mbti: mbti,
          keycapLabels: keycapLabels,
          qrBytes: qrBytes,
          pageFormat: _fitToPrinter(format),
        );
      },
    );

    // [프린터 점검용] 프린터가 알려준 정보를 남겨둡니다.
    final rf = reportedFormat;
    const mmUnit = PdfPageFormat.mm;
    final paperText = rf == null
        ? '용지: 프린터가 알려주지 않음'
        : '용지: ${(rf.width / mmUnit).toStringAsFixed(1)}×'
            '${(rf.height / mmUnit).toStringAsFixed(1)}mm '
            '(여백 좌${(rf.marginLeft / mmUnit).toStringAsFixed(1)} '
            '우${(rf.marginRight / mmUnit).toStringAsFixed(1)})';
    lastPrintInfo =
        '프린터: ${targetPrinter.name} (사용가능: ${targetPrinter.isAvailable})\n'
        '$paperText';

    if (!result) {
      throw Exception('영수증 출력에 실패했습니다.');
    }

    debugPrint('영수증 출력 요청 성공');
  }

  /// 실제 인쇄될 80mm 영수증 PDF 생성
  static Future<Uint8List> _buildReceiptPdf({
    required String orderNumber,
    required String time,
    required String mbti,
    required List<String> keycapLabels,
    required PdfPageFormat pageFormat,
    Uint8List? qrBytes,
  }) async {
    final regularData = await rootBundle.load(
      'assets/fonts/NotoSansKR-Regular.ttf',
    );

    final boldData = await rootBundle.load(
      'assets/fonts/NotoSansKR-Bold.ttf',
    );

    final regularFont = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    final pdf = pw.Document();

    final pw.MemoryImage? qrImage =
        qrBytes != null ? pw.MemoryImage(qrBytes) : null;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 제목
              pw.Center(
                child: pw.Text(
                  '주문 영수증',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 19,
                  ),
                ),
              ),

              pw.SizedBox(height: 4),

              pw.Center(
                child: pw.Text(
                  '나만의 MBTI 키링 만들기',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 10,
                  ),
                ),
              ),

              pw.SizedBox(height: 12),

              pw.Divider(),

              pw.SizedBox(height: 8),

              // 주문번호 크게
              pw.Center(
                child: pw.Text(
                  orderNumber,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 24,
                  ),
                ),
              ),

              pw.SizedBox(height: 12),

              _infoRow(
                label: '접수 시각',
                value: time,
                font: regularFont,
                boldFont: boldFont,
              ),

              pw.SizedBox(height: 5),

              _infoRow(
                label: 'MBTI',
                value: mbti,
                font: regularFont,
                boldFont: boldFont,
              ),

              pw.SizedBox(height: 5),

              _infoRow(
                label: '키캡 색상',
                value: keycapLabels.join(' / '),
                font: regularFont,
                boldFont: boldFont,
              ),

              pw.SizedBox(height: 12),

              pw.Divider(),

              pw.SizedBox(height: 10),

              // QR
              if (qrImage != null) ...[
                pw.Center(
                  child: pw.Image(
                    qrImage,
                    width: 38 * PdfPageFormat.mm,
                    height: 38 * PdfPageFormat.mm,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    'QR을 스캔하여 주문 상태를 확인해주세요.',
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 8,
                    ),
                  ),
                ),
              ] else
                pw.Center(
                  child: pw.Text(
                    'QR 정보를 불러오지 못했습니다.',
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: 8,
                    ),
                  ),
                ),

              pw.SizedBox(height: 14),

              pw.Divider(),

              pw.SizedBox(height: 8),

              pw.Center(
                child: pw.Text(
                  '문제가 발생한 경우 주변 스태프에게 문의해주세요.',
                  style: pw.TextStyle(
                    font: regularFont,
                    fontSize: 8,
                  ),
                ),
              ),

              pw.SizedBox(height: 15),

              // 절단 전 여백
              pw.Text('\n\n'),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _infoRow({
    required String label,
    required String value,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 23 * PdfPageFormat.mm,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}
