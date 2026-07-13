import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:windows_printer/windows_printer.dart';
import 'package:frontend_desktop/core/constants/app_colors.dart';

/// طباعة تذكرة طابور لطابعة Xprinter XP-P323B.
///
/// ارتفاع التذكرة = ارتفاع محتوى الاسم+الرقم فقط (بدون فراغ سفلي).
class QueueTicketPrintService {
  QueueTicketPrintService._();

  static final PdfPageFormat ticketFormat = PdfPageFormat(
    59 * PdfPageFormat.mm,
    28 * PdfPageFormat.mm,
    marginAll: 0,
  );

  static bool _uiFontLoaded = false;
  static const _uiFontFamily = 'QueueTicketNoto';

  /// عرض الرول 59mm @ 203 DPI
  static const int _ticketWidthDots = 472;
  static const double _dpi = 203;

  static Future<void> showPrintPrompt({
    required String name,
    required int number,
  }) async {
    await Get.dialog<void>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'تمت الإضافة للطابور',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$number',
              style: GoogleFonts.cairo(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                height: 1,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text(
              'إغلاق',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Get.back<void>();
              await Future<void>.delayed(const Duration(milliseconds: 250));
              try {
                final method = await printTicket(name: name, number: number);
                Get.snackbar(
                  'تمت الطباعة',
                  'تم الإرسال عبر: $method',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.success,
                  colorText: AppColors.white,
                  duration: const Duration(seconds: 5),
                );
              } catch (e) {
                debugPrint('❌ [QueueTicketPrint] UI error: $e');
                Get.snackbar(
                  'تنبيه',
                  'فشلت طباعة التذكرة\n$e',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppColors.error,
                  colorText: AppColors.white,
                  duration: const Duration(seconds: 8),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.print_rounded, size: 20),
            label: Text(
              'طباعة الرقم',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  static Future<void> _ensureUiFont() async {
    if (_uiFontLoaded) return;
    final data = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Bold.ttf',
    );
    final loader = FontLoader(_uiFontFamily)..addFont(Future.value(data));
    await loader.load();
    _uiFontLoaded = true;
  }

  static Future<({Uint8List rgba, int width, int height, Uint8List png})>
      _renderTicketImage({
    required String name,
    required int number,
  }) async {
    await _ensureUiFont();

    const width = _ticketWidthDots;
    const padX = 12.0;
    const padY = 16.0;
    const gap = 12.0;
    // مسافة بيضاء بعد المحتوى للتمزيق (~12mm @ 203 DPI)
    const tearMarginDots = 96;

    ui.Paragraph buildParagraph({
      required String text,
      required double fontSize,
      required FontWeight weight,
      int maxLines = 2,
    }) {
      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontFamily: _uiFontFamily,
          fontSize: fontSize,
          fontWeight: weight,
          maxLines: maxLines,
          height: 1.0,
        ),
      )
        ..pushStyle(
          ui.TextStyle(
            color: Colors.black,
            fontFamily: _uiFontFamily,
            fontSize: fontSize,
            fontWeight: weight,
            height: 1.0,
          ),
        )
        ..addText(text);
      return builder.build()
        ..layout(ui.ParagraphConstraints(width: width - padX * 2));
    }

    final namePara = buildParagraph(
      text: name,
      fontSize: 42,
      weight: FontWeight.w700,
    );
    final numberPara = buildParagraph(
      text: '$number',
      fontSize: 140,
      weight: FontWeight.w800,
      maxLines: 1,
    );

    final contentHeight =
        (padY * 2 + namePara.height + gap + numberPara.height).ceil();
    final height = (contentHeight + tearMarginDots).clamp(200, 560);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );

    final linePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // خط فوق الاسم وخط تحت الرقم فقط (بدون يمين/يسار)
    const lineInset = 20.0;
    canvas.drawLine(
      const Offset(lineInset, 6),
      Offset(width - lineInset, 6),
      linePaint,
    );
    canvas.drawLine(
      Offset(lineInset, contentHeight - 6.0),
      Offset(width - lineInset, contentHeight - 6.0),
      linePaint,
    );

    var y = padY;
    canvas.drawParagraph(namePara, Offset(padX, y));
    y += namePara.height + gap;
    canvas.drawParagraph(numberPara, Offset(padX, y));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final rgbaData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (rgbaData == null || pngData == null) {
      throw StateError('تعذر إنشاء صورة التذكرة');
    }

    final rgba = rgbaData.buffer.asUint8List();
    if (_countDarkPixels(rgba) < 80) {
      throw StateError('صورة التذكرة فارغة — تعذر رسم النص');
    }

    return (
      rgba: rgba,
      width: width,
      height: height,
      png: pngData.buffer.asUint8List(),
    );
  }

  static String _heightMm(int heightDots) {
    final mm = heightDots / _dpi * 25.4;
    return mm.toStringAsFixed(1);
  }

  static int _countDarkPixels(Uint8List rgba) {
    var count = 0;
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      final lum = (rgba[i] * 77 + rgba[i + 1] * 150 + rgba[i + 2] * 29) >> 8;
      if (lum < 160) count++;
    }
    return count;
  }

  /// ESC/POS raster فقط — الطابعة على وضع ESC ولا تفهم TSPL
  static Uint8List _buildEscPosRasterJob({
    required Uint8List rgba,
    required int width,
    required int height,
  }) {
    final widthBytes = (width + 7) ~/ 8;
    final out = BytesBuilder(copy: false);

    // ESC @ تهيئة
    out.add([0x1B, 0x40]);
    // محاذاة وسط
    out.add([0x1B, 0x61, 0x01]);

    // GS v 0 m=0 — التغذية = ارتفاع الصورة فقط (بدون أوامر TSPL وبدون feed إضافي)
    out.add([0x1D, 0x76, 0x30, 0x00]);
    out.add([widthBytes & 0xFF, (widthBytes >> 8) & 0xFF]);
    out.add([height & 0xFF, (height >> 8) & 0xFF]);

    for (var y = 0; y < height; y++) {
      for (var xb = 0; xb < widthBytes; xb++) {
        var b = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = xb * 8 + bit;
          if (x >= width) continue;
          final i = (y * width + x) * 4;
          final lum =
              (rgba[i] * 77 + rgba[i + 1] * 150 + rgba[i + 2] * 29) >> 8;
          if (lum < 160) {
            b |= (0x80 >> bit);
          }
        }
        out.addByte(b);
      }
    }

    return out.toBytes();
  }

  static Future<Uint8List> _pngToPdf(Uint8List pngBytes) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    pdf.addPage(
      pw.Page(
        pageFormat: ticketFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.SizedBox(
          width: ticketFormat.width,
          height: ticketFormat.height,
          child: pw.Image(image, fit: pw.BoxFit.fill),
        ),
      ),
    );
    return pdf.save();
  }

  static Future<String?> _findXprinterName() async {
    try {
      final printers = await WindowsPrinter.getAvailablePrinters();
      debugPrint('🖨️ [QueueTicketPrint] printers: $printers');
      for (final name in printers) {
        final lower = name.toLowerCase();
        if (lower.contains('xp-p323') ||
            lower.contains('p323') ||
            lower.contains('xprinter')) {
          return name;
        }
      }
      if (printers.isNotEmpty) return printers.first;
    } catch (e) {
      debugPrint('⚠️ [QueueTicketPrint] list printers failed: $e');
    }
    return null;
  }

  static Future<bool> _printViaWin32Raw({
    required String printerName,
    required Uint8List data,
  }) async {
    final binPath =
        '${Directory.systemTemp.path}\\farah_raw_${DateTime.now().millisecondsSinceEpoch}.bin';
    final ps1Path =
        '${Directory.systemTemp.path}\\farah_raw_${DateTime.now().millisecondsSinceEpoch}.ps1';

    try {
      await File(binPath).writeAsBytes(data, flush: true);

      const script = r'''
$ErrorActionPreference = 'Stop'
$printer = $args[0]
$binPath = $args[1]
$data = [System.IO.File]::ReadAllBytes($binPath)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class FarahRawPrint {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
  public class DOCINFOA {
    [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
  }
  [DllImport("winspool.Drv", EntryPoint="OpenPrinterA", SetLastError=true, CharSet=CharSet.Ansi)]
  public static extern bool OpenPrinter([MarshalAs(UnmanagedType.LPStr)] string szPrinter, out IntPtr hPrinter, IntPtr pd);
  [DllImport("winspool.Drv", EntryPoint="ClosePrinter", SetLastError=true)]
  public static extern bool ClosePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="StartDocPrinterA", SetLastError=true, CharSet=CharSet.Ansi)]
  public static extern bool StartDocPrinter(IntPtr hPrinter, Int32 level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);
  [DllImport("winspool.Drv", EntryPoint="EndDocPrinter", SetLastError=true)]
  public static extern bool EndDocPrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="StartPagePrinter", SetLastError=true)]
  public static extern bool StartPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="EndPagePrinter", SetLastError=true)]
  public static extern bool EndPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="WritePrinter", SetLastError=true)]
  public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, Int32 dwCount, out Int32 dwWritten);

  public static string Send(string printer, byte[] data) {
    IntPtr h;
    if (!OpenPrinter(printer, out h, IntPtr.Zero)) {
      return "FAIL OpenPrinter err=" + Marshal.GetLastWin32Error();
    }
    var di = new DOCINFOA();
    di.pDocName = "FarahQueueTicket";
    di.pDataType = "RAW";
    if (!StartDocPrinter(h, 1, di)) {
      var err = Marshal.GetLastWin32Error();
      ClosePrinter(h);
      return "FAIL StartDocPrinter err=" + err;
    }
    if (!StartPagePrinter(h)) {
      EndDocPrinter(h); ClosePrinter(h);
      return "FAIL StartPagePrinter";
    }
    IntPtr p = Marshal.AllocCoTaskMem(data.Length);
    Marshal.Copy(data, 0, p, data.Length);
    int written;
    bool ok = WritePrinter(h, p, data.Length, out written);
    Marshal.FreeCoTaskMem(p);
    EndPagePrinter(h);
    EndDocPrinter(h);
    ClosePrinter(h);
    if (!ok || written != data.Length) {
      return "FAIL WritePrinter written=" + written + " expected=" + data.Length;
    }
    return "OK written=" + written;
  }
}
"@

$result = [FarahRawPrint]::Send($printer, $data)
Write-Output $result
if ($result -notlike 'OK*') { exit 1 }
''';
      await File(ps1Path).writeAsString(script, flush: true);

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          ps1Path,
          printerName,
          binPath,
        ],
        runInShell: false,
      );

      final out = result.stdout.toString().trim();
      debugPrint(
        '🖨️ [QueueTicketPrint] Win32RAW exit=${result.exitCode} out=$out err=${result.stderr}',
      );
      return result.exitCode == 0 && out.contains('OK');
    } catch (e) {
      debugPrint('⚠️ [QueueTicketPrint] Win32RAW failed: $e');
      return false;
    } finally {
      _scheduleDelete(binPath);
      _scheduleDelete(ps1Path);
    }
  }

  static Uint8List _rgbaToBmp(Uint8List rgba, int width, int height) {
    final rowSize = ((width * 3 + 3) ~/ 4) * 4;
    final pixelBytes = rowSize * height;
    final fileSize = 54 + pixelBytes;
    final out = ByteData(fileSize);
    final bytes = out.buffer.asUint8List();

    out.setUint8(0, 0x42);
    out.setUint8(1, 0x4D);
    out.setUint32(2, fileSize, Endian.little);
    out.setUint32(10, 54, Endian.little);
    out.setUint32(14, 40, Endian.little);
    out.setInt32(18, width, Endian.little);
    out.setInt32(22, height, Endian.little);
    out.setUint16(26, 1, Endian.little);
    out.setUint16(28, 24, Endian.little);
    out.setUint32(34, pixelBytes, Endian.little);

    for (var y = 0; y < height; y++) {
      final srcY = height - 1 - y;
      final dstRow = 54 + y * rowSize;
      for (var x = 0; x < width; x++) {
        final si = (srcY * width + x) * 4;
        final di = dstRow + x * 3;
        bytes[di] = rgba[si + 2];
        bytes[di + 1] = rgba[si + 1];
        bytes[di + 2] = rgba[si];
      }
    }
    return bytes;
  }

  /// GDI: يطبع نفس صورة التذكرة الضيقة بمقاس ورق مطابق لارتفاعها
  static Future<bool> _printViaGdiTicket({
    required String printerName,
    required Uint8List rgba,
    required int width,
    required int height,
  }) async {
    final bmpPath =
        '${Directory.systemTemp.path}\\farah_gdi_${DateTime.now().millisecondsSinceEpoch}.bmp';
    final ps1Path =
        '${Directory.systemTemp.path}\\farah_gdi_${DateTime.now().millisecondsSinceEpoch}.ps1';

    try {
      await File(bmpPath).writeAsBytes(_rgbaToBmp(rgba, width, height), flush: true);

      // hundredths of inch
      final paperW = (59 / 25.4 * 100).round(); // ~232
      final paperH = (height / _dpi * 100).round().clamp(60, 400);

      const script = r'''
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$printer = $args[0]
$bmpPath = $args[1]
$paperW = [int]$args[2]
$paperH = [int]$args[3]

$doc = New-Object System.Drawing.Printing.PrintDocument
$doc.DocumentName = 'FarahQueueTicket'
$doc.PrinterSettings.PrinterName = $printer
if (-not $doc.PrinterSettings.IsValid) { throw "Printer not valid: $printer" }
$doc.PrintController = New-Object System.Drawing.Printing.StandardPrintController
$doc.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0,0,0,0)
$doc.DefaultPageSettings.Landscape = $false

$paper = New-Object System.Drawing.Printing.PaperSize('FarahTicketTight', $paperW, $paperH)
$paper.RawKind = 256
$doc.DefaultPageSettings.PaperSize = $paper

foreach ($src in $doc.PrinterSettings.PaperSources) {
  if ($src.SourceName -like '*Continuous*' -or $src.SourceName -like '*Roll*') {
    $doc.DefaultPageSettings.PaperSource = $src
    break
  }
}

$script:img = [System.Drawing.Image]::FromFile($bmpPath)
try {
  $doc.add_PrintPage({
    param($s, $e)
    $e.Graphics.DrawImage($script:img, $e.PageBounds)
    $e.HasMorePages = $false
  })
  $doc.Print()
  Write-Output "OK gdi-image paper=$($paper.PaperName) $($paper.Width)x$($paper.Height)"
} finally {
  $script:img.Dispose()
}
''';
      await File(ps1Path).writeAsString(script, flush: true);

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          ps1Path,
          printerName,
          bmpPath,
          '$paperW',
          '$paperH',
        ],
        runInShell: false,
      );

      debugPrint(
        '🖨️ [QueueTicketPrint] GDI exit=${result.exitCode} '
        'out=${result.stdout} err=${result.stderr}',
      );
      return result.exitCode == 0 && result.stdout.toString().contains('OK');
    } catch (e) {
      debugPrint('⚠️ [QueueTicketPrint] GDI failed: $e');
      return false;
    } finally {
      _scheduleDelete(bmpPath);
      _scheduleDelete(ps1Path);
    }
  }

  static Future<bool> _printViaEscPos({
    required String printerName,
    required Uint8List rgba,
    required int width,
    required int height,
  }) async {
    final raw = _buildEscPosRasterJob(
      rgba: rgba,
      width: width,
      height: height,
    );
    final ok = await _printViaWin32Raw(printerName: printerName, data: raw);
    debugPrint('🖨️ [QueueTicketPrint] ESC/POS raster → $ok (${raw.length}b)');
    if (ok) return true;

    try {
      final pluginOk = await WindowsPrinter.printRawData(
        printerName: printerName,
        data: raw,
        useRawDatatype: true,
      );
      debugPrint('🖨️ [QueueTicketPrint] ESC/POS plugin → $pluginOk');
      return pluginOk;
    } catch (e) {
      debugPrint('⚠️ [QueueTicketPrint] ESC/POS plugin failed: $e');
      return false;
    }
  }

  static Future<bool> _printViaDirectPdf({
    required String printerName,
    required Uint8List pngBytes,
  }) async {
    try {
      final printers = await Printing.listPrinters();
      Printer? target;
      for (final p in printers) {
        if (p.name == printerName ||
            p.name.toLowerCase().contains('xprinter') ||
            p.name.toLowerCase().contains('p323')) {
          target = p;
          break;
        }
      }
      if (target == null) return false;

      final pdfBytes = await _pngToPdf(pngBytes);
      final ok = await Printing.directPrintPdf(
        printer: target,
        name: 'queue_ticket',
        format: ticketFormat,
        usePrinterSettings: true,
        onLayout: (_) async => pdfBytes,
      );
      debugPrint('🖨️ [QueueTicketPrint] directPrintPdf → $ok');
      return ok;
    } catch (e) {
      debugPrint('⚠️ [QueueTicketPrint] directPrintPdf failed: $e');
      return false;
    }
  }

  static void _scheduleDelete(String path) {
    Future<void>.delayed(const Duration(seconds: 15), () {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    });
  }

  static Future<String> printTicket({
    required String name,
    required int number,
  }) async {
    if (!Platform.isWindows) {
      throw StateError('طباعة التذاكر متاحة على ويندوز فقط');
    }

    final printerName = await _findXprinterName();
    if (printerName == null) {
      throw StateError('لم يتم العثور على طابعة في ويندوز');
    }
    debugPrint('🖨️ [QueueTicketPrint] using printer: $printerName');

    final rendered = await _renderTicketImage(name: name, number: number);
    debugPrint(
      '🖨️ [QueueTicketPrint] ticket ${rendered.width}x${rendered.height} '
      '(~${_heightMm(rendered.height)}mm feed)',
    );

    // XP-P323B عند المستخدم على وضع ESC — أوامر TSPL تُطبع كنص/رموز (مو تذكرة)
    // لذلك ESC/POS أولاً فقط، ثم GDI. لا نستخدم TSPL.

    if (await _printViaEscPos(
      printerName: printerName,
      rgba: rendered.rgba,
      width: rendered.width,
      height: rendered.height,
    )) {
      return 'ESC/POS ($printerName)';
    }

    if (await _printViaGdiTicket(
      printerName: printerName,
      rgba: rendered.rgba,
      width: rendered.width,
      height: rendered.height,
    )) {
      return 'GDI ($printerName)';
    }

    if (await _printViaDirectPdf(
      printerName: printerName,
      pngBytes: rendered.png,
    )) {
      return 'PDF ($printerName)';
    }

    final pdfBytes = await _pngToPdf(rendered.png);
    await Printing.layoutPdf(
      name: 'تذكرة_الطابور_$number',
      format: PdfPageFormat(
        59 * PdfPageFormat.mm,
        double.parse(_heightMm(rendered.height)) * PdfPageFormat.mm,
        marginAll: 0,
      ),
      usePrinterSettings: true,
      onLayout: (_) async => pdfBytes,
    );
    return 'دايلوك ويندوز';
  }
}
