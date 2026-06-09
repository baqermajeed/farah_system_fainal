import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';

class QueueWindowService {
  QueueWindowService._();

  static const queueDisplayType = 'queue_display';

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

  static Future<void> openOrFocusDisplayWindow() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('شاشة العرض المنفصلة متاحة على Windows فقط');
    }

    final controllers = await WindowController.getAll();
    for (final controller in controllers) {
      if (_isQueueDisplayWindow(controller.arguments)) {
        await controller.show();
        return;
      }
    }

    final display = await _pickDisplayMonitor();
    final position = display.visiblePosition ?? Offset.zero;
    final size = display.visibleSize ?? display.size;

    final arguments = jsonEncode({
      'type': queueDisplayType,
      'x': position.dx,
      'y': position.dy,
      'width': size.width,
      'height': size.height,
    });

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

  static Future<Display> _pickDisplayMonitor() async {
    final displays = await ScreenRetriever.instance.getAllDisplays();
    if (displays.isEmpty) {
      throw StateError('لم يتم العثور على شاشة');
    }
    if (displays.length >= 2) {
      return displays[1];
    }
    return displays.first;
  }
}
