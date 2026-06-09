import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class QueueAnnouncementService {
  QueueAnnouncementService._();

  static final QueueAnnouncementService instance = QueueAnnouncementService._();

  final AudioPlayer _bellPlayer = AudioPlayer();
  final AudioPlayer _numberPlayer = AudioPlayer();
  bool _initialized = false;
  bool _isSpeaking = false;

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
    debugPrint('✅ [QueueAnnouncement] ready (bell + number only)');
  }

  Future<void> announcePatient({
    required int number,
    required String name,
  }) async {
    if (!_initialized) await init();
    if (!Platform.isWindows) return;
    if (_isSpeaking) {
      debugPrint('⚠️ [QueueAnnouncement] Already speaking, skipped');
      return;
    }

    final numberAsset = _numberAssetFor(number);
    if (numberAsset == null) {
      debugPrint('⚠️ [QueueAnnouncement] Number out of range: $number');
      return;
    }

    _isSpeaking = true;
    try {
      final bellAsset = await _resolveBellAsset();
      if (bellAsset != null) {
        await _prepareAssetOnPlayer(_bellPlayer, bellAsset);
      }
      await _prepareAssetOnPlayer(_numberPlayer, numberAsset);

      if (bellAsset != null) {
        await _playPreparedPlayer(_bellPlayer, timeout: const Duration(seconds: 8));
      }
      await _playPreparedPlayer(_numberPlayer, timeout: const Duration(seconds: 20));
    } catch (e) {
      debugPrint('⚠️ [QueueAnnouncement] Speak failed: $e');
    } finally {
      _isSpeaking = false;
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

  Future<void> _prepareAssetOnPlayer(AudioPlayer player, String assetPath) async {
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
