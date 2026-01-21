import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// خدمة الطابعة الحرارية (TSC) للطباعة المباشرة RAW باستخدام أوامر TSPL
class ThermalPrinterService {
  static const String _printerName = 'TSC TTP-244';

  /// طباعة لاصق مريض يحتوي على QR + Barcode + نص
  ///
  /// مثال استخدام:
  /// `ThermalPrinterService().printPatientLabel('PAT-2026-001');`
  void printPatientLabel(String patientId, {String? patientName}) {
    if (!Platform.isWindows) {
      throw UnsupportedError('Thermal printing is only supported on Windows.');
    }

    final hPrinter = calloc<HANDLE>();
    final docInfo = calloc<DOC_INFO_1>();

    try {
      // 1) فتح الطابعة
      final printerNamePtr = _printerName.toNativeUtf16();
      final nullPtr = nullptr;

      final opened = OpenPrinter(printerNamePtr, hPrinter, nullPtr.cast());
      if (opened == 0) {
        throw Exception('فشل فتح الطابعة ($_printerName). تأكد من الاسم والتعريف.');
      }

      // 2) إعداد معلومات المستند (RAW)
      final docNamePtr = 'Patient Label'.toNativeUtf16();
      final dataTypePtr = 'RAW'.toNativeUtf16(); // مهم جداً: نوع RAW

      docInfo.ref
        ..pDocName = docNamePtr
        ..pOutputFile = nullptr
        ..pDatatype = dataTypePtr;

      final hPrinterValue = hPrinter.value;

      // 3) بدء المستند والصفحة
      if (StartDocPrinter(hPrinterValue, 1, docInfo.cast()) == 0) {
        throw Exception('فشل StartDocPrinter');
      }

      if (StartPagePrinter(hPrinterValue) == 0) {
        throw Exception('فشل StartPagePrinter');
      }

      // 4) بناء أوامر TSPL
      // ملاحظة: يمكن استخدام patientName في النص إذا أحببت، حالياً نطابق المطلوب (Patient ID فقط)
      final String tspl = '''
SIZE 60 mm,40 mm
GAP 2 mm,0
DIRECTION 1
CLS
QRCODE 20,20,L,6,A,0,"$patientId"
BARCODE 20,180,"128",80,1,0,2,2,"$patientId"
TEXT 20,280,"0",0,1,1,"Patient ID: $patientId"
PRINT 1
''';

      // 5) تحويل النص إلى بايتات وإرسالها كـ RAW
      final units = tspl.codeUnits;
      final dataPtr = calloc<Uint8>(units.length);
      for (var i = 0; i < units.length; i++) {
        dataPtr[i] = units[i];
      }

      final bytesWritten = calloc<Uint32>();

      final success = WritePrinter(
        hPrinterValue,
        dataPtr.cast(),
        units.length,
        bytesWritten,
      );

      if (success == 0 || bytesWritten.value != units.length) {
        throw Exception('فشل WritePrinter (لم يتم إرسال جميع البيانات إلى الطابعة).');
      }

      // 6) إنهاء الصفحة والمستند
      EndPagePrinter(hPrinterValue);
      EndDocPrinter(hPrinterValue);
    } finally {
      // تنظيف الموارد
      if (hPrinter.value != 0) {
        ClosePrinter(hPrinter.value);
      }
      calloc.free(hPrinter);
      calloc.free(docInfo);
    }
  }
}


