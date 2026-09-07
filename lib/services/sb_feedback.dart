import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Quiet feedback: haptics for confirms, sound only when a bill lands or is paid.
class SbFeedback {
  SbFeedback._();

  static const _haptics = MethodChannel('slickbill/haptics');
  static AudioPlayer? _player;
  static var _playerReady = false;
  static var _playerFailed = false;

  static Future<void> selection() async {
    // Picker-style selection clicks are easy to miss through a case.
    _impact(defaultTargetPlatform == TargetPlatform.iOS ? 'light' : 'selection');
  }

  static Future<void> confirm() async => _impact('light');

  static Future<void> medium() async => _impact('medium');

  static DateTime? _lastSettledAt;
  static DateTime? _lastReceivedAt;
  static const _soundWindow = Duration(seconds: 6);

  static Future<void> settled() async {
    if (kIsWeb) return;
    if (_throttled(_lastSettledAt)) return;
    _lastSettledAt = DateTime.now();
    _impact('medium');
    unawaited(_play('sounds/paid.wav'));
  }

  static Future<void> received() async {
    if (kIsWeb) return;
    if (_throttled(_lastReceivedAt)) return;
    _lastReceivedAt = DateTime.now();
    _impact('medium');
    unawaited(_play('sounds/received.wav'));
  }

  static bool _throttled(DateTime? previous) {
    return previous != null &&
        DateTime.now().difference(previous) < _soundWindow;
  }

  static Future<void> error() async => _impact('error');

  static void _impact(String kind) {
    if (kIsWeb) return;
    unawaited(_playImpact(kind));
  }

  static Future<void> _playImpact(String kind) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _haptics.invokeMethod('play', kind);
        return;
      } catch (_) {
        // Channel missing (hot restart, tests) — fall back.
      }
    }
    await _fallback(kind);
  }

  static Future<void> _fallback(String kind) async {
    switch (kind) {
      case 'selection':
        await HapticFeedback.selectionClick();
      case 'light':
        await HapticFeedback.lightImpact();
      case 'heavy' || 'error':
        await HapticFeedback.heavyImpact();
      default:
        await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> _play(String asset) async {
    try {
      await _ensurePlayer();
      final player = _player;
      if (player == null) return;
      await player.stop();
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('[SbFeedback] sound failed: $e');
    }
  }

  static Future<void> _ensurePlayer() async {
    if (_playerReady || _playerFailed || kIsWeb) return;

    try {
      // `ambient` honors the silent switch. Do not pass mixWithOthers —
      // audioplayers only allows that option on playback / playAndRecord.
      final context = AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.ambient,
        ),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      );

      final player = AudioPlayer();
      await AudioPlayer.global.setAudioContext(context);
      await player.setAudioContext(context);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1);
      _player = player;
      _playerReady = true;
    } catch (e) {
      _playerFailed = true;
      debugPrint('[SbFeedback] audio setup failed: $e');
    }
  }
}
