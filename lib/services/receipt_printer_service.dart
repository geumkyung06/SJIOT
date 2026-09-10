import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPrinterService {
  // SLK-TS100 = 80mm 영수증 프린터
  static final PdfPageFormat _receiptFormat = PdfPageFormat(
    80 * PdfPageFormat.mm,
    180 * PdfPageFormat.mm,
    marginAll: 4 * PdfPageFormat.mm,
  );

  /// 실제 SLK-TS100으로 영수증 출력
  static Future<void> printReceipt({
    required String orderNumber,
    required String time,
    required String mbti,
    required List<String> keycapLabels,
    Uint8List? qrBytes,
  }) async {
    // 1. Windows에 설치된 프린터 목록 조회
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

    // 2. SLK-TS100 찾기
    Printer? targetPrinter;

    for (final printer in printers) {
      final name = printer.name.toLowerCase();

      if (name.contains('slk-ts100') ||
          name.contains('slk ts100') ||
          name.contains('sewoo')) {
        targetPrinter = printer;
        break;
      }
    }

    if (targetPrinter == null) {
      throw Exception(
        'SLK-TS100 프린터를 찾을 수 없습니다. '
        'Windows 프린터 설정에서 먼저 프린터가 설치되어 있는지 확인해주세요.',
      );
    }

    debugPrint('선택된 프린터: ${targetPrinter.name}');

    // 3. 영수증 PDF 생성
    final pdfBytes = await _buildReceiptPdf(
      orderNumber: orderNumber,
      time: time,
      mbti: mbti,
      keycapLabels: keycapLabels,
      qrBytes: qrBytes,
    );

    // 4. SLK-TS100으로 바로 출력
    final result = await Printing.directPrintPdf(
      printer: targetPrinter,
      name: 'receipt_$orderNumber',
      format: _receiptFormat,
      dynamicLayout: false,
      onLayout: (_) async => pdfBytes,
    );

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
        pageFormat: _receiptFormat,
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
                  '딸깍 키링 스튜디오',
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
