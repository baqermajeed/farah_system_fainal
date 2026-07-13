import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class _AnnounceRequest {
  const _AnnounceRequest({required this.number, required this.name});

  final int number;
  final String name;
}

class QueueAnnouncementService {
  QueueAnnouncementService._();

  static final QueueAnnouncementService instance = QueueAnnouncementService._();

  final AudioPlayer _bellPlayer = AudioPlayer();
  final AudioPlayer _numberPlayer = AudioPlayer();
  bool _initialized = false;
  bool _processing = false;
  final List<_AnnounceRequest> _pending = <_AnnounceRequest>[];

  static const List<String> _bellCandidates = [
    'audio/الجرس.mp3',
    'audio/جرس.mp3',
    'audio/bell.mp3',
  ];

  Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isWindows) {
      debugPrint('⚠️ [QueueAnnouncement] TTS supported on Windows only');
      return;
    }
    await _configurePlayer(_bellPlayer);
    await _configurePlayer(_numberPlayer);
    _initialized = true;
    debugPrint('✅ [QueueAnnouncement] ready (queued bell + number)');
  }

  /// يضيف النداء للطابور — لا يتجاهل الاستدعاءات السريعة المتتالية
  Future<void> announcePatient({
    required int number,
    required String name,
  }) async {
    if (!_initialized) await init();
    if (!Platform.isWindows) return;

    final numberAsset = _numberAssetFor(number);
    if (numberAsset == null) {
      debugPrint('⚠️ [QueueAnnouncement] Number out of range: $number');
      return;
    }

    _pending.add(_AnnounceRequest(number: number, name: name));
    debugPrint(
      '🔔 [QueueAnnouncement] queued #$number ($name) pending=${_pending.length}',
    );
    await _drainQueue();
  }

  Future<void> _drainQueue() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_pending.isNotEmpty) {
        final next = _pending.removeAt(0);
        await _speak(next);
      }
    } finally {
      _processing = false;
      // إذا أُضيف نداء أثناء finally
      if (_pending.isNotEmpty) {
        await _drainQueue();
      }
    }
  }

  Future<void> _speak(_AnnounceRequest request) async {
    final numberAsset = _numberAssetFor(request.number);
    if (numberAsset == null) return;

    debugPrint(
      '🔊 [QueueAnnouncement] speaking #${request.number} (${request.name})',
    );
    try {
      final bellAsset = await _resolveBellAsset();
      if (bellAsset != null) {
        await _prepareAssetOnPlayer(_bellPlayer, bellAsset);
      }
      await _prepareAssetOnPlayer(_numberPlayer, numberAsset);

      if (bellAsset != null) {
        await _playPreparedPlayer(
          _bellPlayer,
          timeout: const Duration(seconds: 8),
        );
      }
      await _playPreparedPlayer(
        _numberPlayer,
        timeout: const Duration(seconds: 20),
      );
    } catch (e) {
      debugPrint('⚠️ [QueueAnnouncement] Speak failed: $e');
    }
  }

  Future<void> _configurePlayer(AudioPlayer player) async {
    await player.setVolume(1.0);
    await player.setReleaseMode(ReleaseMode.stop);
  }

  String? _numberAssetFor(int number) {
    if (number < 1 || number > 100) return null;
    return 'audio/$number.mp3';
  }

  Future<String?> _resolveBellAsset() async {
    for (final candidate in _bellCandidates) {
      try {
        await _bellPlayer.setSource(AssetSource(candidate));
        return candidate;
      } catch (_) {
        continue;
      }
    }
    debugPrint('ℹ️ [QueueAnnouncement] Bell not found, continue without bell');
    return null;
  }

  Future<void> _prepareAssetOnPlayer(
    AudioPlayer player,
    String assetPath,
  ) async {
    await player.stop();
    await player.setSource(AssetSource(assetPath));
    await player.setVolume(1.0);
    await player.seek(Duration.zero);
  }

  Future<bool> _playPreparedPlayer(
    AudioPlayer player, {
    required Duration timeout,
  }) async {
    try {
      await player.seek(Duration.zero);
      await player.resume();
      await player.onPlayerComplete.first.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Playback timed out');
        },
      );
      return true;
    } on Exception catch (e) {
      debugPrint('⚠️ [QueueAnnouncement] Player error: $e');
      return false;
    }
  }
}
