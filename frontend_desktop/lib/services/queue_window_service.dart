import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';

class QueueWindowService {
  QueueWindowService._();

  static const queueDisplayType = 'queue_display';
  static const repositionMethod = 'reposition';

  static const _syncChannel = WindowMethodChannel(
    'farah_queue_sync',
    mode: ChannelMode.unidirectional,
  );

  static Future<void> notifyDisplayUpdate(Map<String, dynamic> payload) async {
    if (!Platform.isWindows) return;
    try {
      await _syncChannel.invokeMethod('refresh', payload);
    } catch (_) {
      // شاشة العرض غير مفتوحة
    }
  }

  static Future<void> notifyDisplayUpdateWithRetry(
    Map<String, dynamic> payload, {
    int attempts = 15,
  }) async {
    if (!Platform.isWindows) return;
    for (var i = 0; i < attempts; i++) {
      try {
        await _syncChannel.invokeMethod('refresh', payload);
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  static Future<void> setupDisplayChannel(
    void Function(Map<String, dynamic> data) onRefresh,
  ) async {
    await _syncChannel.setMethodCallHandler((call) async {
      if (call.method == 'refresh' && call.arguments is Map) {
        onRefresh(Map<String, dynamic>.from(call.arguments as Map));
      }
      return null;
    });
  }

  static Future<bool> isDisplayWindowOpen() async {
    if (!Platform.isWindows) return false;
    final controllers = await WindowController.getAll();
    for (final controller in controllers) {
      if (_isQueueDisplayWindow(controller.arguments)) {
        return true;
      }
    }
    return false;
  }

  /// إحداثيات الشاشة الثانية (شاشة Hikvision العمودية) بالحجم الكامل.
  static Future<Map<String, double>> resolveDisplayBounds() async {
    final display = await _pickDisplayMonitor();
    final position = display.visiblePosition ?? Offset.zero;
    // استخدم الحجم الكامل وليس visibleSize (يتأثر بشريط المهام ويختلف بين الأجهزة)
    final size = display.size;
    return {
      'x': position.dx,
      'y': position.dy,
      'width': size.width,
      'height': size.height,
      'scaleFactor': (display.scaleFactor ?? 1).toDouble(),
    };
  }

  static Future<void> openOrFocusDisplayWindow() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('شاشة العرض المنفصلة متاحة على Windows فقط');
    }

    final bounds = await resolveDisplayBounds();
    debugPrint(
      '🖥️ [QueueDisplay] Target monitor: '
      '(${bounds['x']}, ${bounds['y']}) '
      '${bounds['width']?.toInt()}×${bounds['height']?.toInt()} '
      'scale=${bounds['scaleFactor']}',
    );

    final arguments = jsonEncode({
      'type': queueDisplayType,
      ...bounds,
    });

    final controllers = await WindowController.getAll();
    for (final controller in controllers) {
      if (_isQueueDisplayWindow(controller.arguments)) {
        try {
          await controller.invokeMethod(repositionMethod, bounds);
        } catch (_) {
          // النافذة قد تكون ما زالت تقلع
        }
        await controller.show();
        return;
      }
    }

    final controller = await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: arguments,
      ),
    );
    await controller.show();
  }

  static bool isQueueDisplayWindow(String? arguments) {
    if (arguments == null || arguments.isEmpty) return false;
    return _isQueueDisplayWindow(arguments);
  }

  static Map<String, dynamic> parseArguments(String arguments) {
    if (arguments.isEmpty) return {};
    try {
      final decoded = jsonDecode(arguments);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
    } catch (_) {}
    return {};
  }

  static bool _isQueueDisplayWindow(String arguments) {
    if (arguments == queueDisplayType) return true;
    final config = parseArguments(arguments);
    return config['type'] == queueDisplayType;
  }

  /// اختيار شاشة العرض الثابتة (Hikvision عمودية 55").
  /// لا يعتمد على displays[1] لأن ترتيب الشاشات يتغير بين أجهزة Windows.
  static Future<Display> _pickDisplayMonitor() async {
    final displays = await ScreenRetriever.instance.getAllDisplays();
    if (displays.isEmpty) {
      throw StateError('لم يتم العثور على شاشة');
    }
    if (displays.length == 1) return displays.first;

    final primary = await ScreenRetriever.instance.getPrimaryDisplay();

    bool isPortrait(Display d) => d.size.height > d.size.width + 1;
    bool sameDisplay(Display a, Display b) => a.id == b.id;

    int areaOf(Display d) =>
        (d.size.width * d.size.height).round().abs();

    void sortLargestFirst(List<Display> list) {
      list.sort((a, b) => areaOf(b).compareTo(areaOf(a)));
    }

    // 1) شاشة ثانوية عمودية = شاشة الطابور Hikvision
    final secondaryPortrait = displays
        .where((d) => !sameDisplay(d, primary) && isPortrait(d))
        .toList();
    if (secondaryPortrait.isNotEmpty) {
      sortLargestFirst(secondaryPortrait);
      return secondaryPortrait.first;
    }

    // 2) أي شاشة ثانوية (أكبر مساحة)
    final secondary =
        displays.where((d) => !sameDisplay(d, primary)).toList();
    if (secondary.isNotEmpty) {
      sortLargestFirst(secondary);
      return secondary.first;
    }

    // 3) أي شاشة عمودية
    final portraits = displays.where(isPortrait).toList();
    if (portraits.isNotEmpty) {
      sortLargestFirst(portraits);
      return portraits.first;
    }

    return displays[1];
  }
}
