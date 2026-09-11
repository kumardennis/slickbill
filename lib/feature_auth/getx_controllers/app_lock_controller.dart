import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:slickbill/services/biometric_auth_service.dart';
import 'package:slickbill/services/sb_feedback.dart';

class AppLockController extends GetxController with WidgetsBindingObserver {
  static const gracePeriod = Duration(seconds: 12);
  static const _externalAuthTimeout = Duration(minutes: 15);
  static const _postAuthLifecycleGrace = Duration(milliseconds: 800);

  final BiometricAuthService _auth = BiometricAuthService();

  final isUnlocked = false.obs;
  final isAuthenticating = false.obs;
  final routeEpoch = 0.obs;

  DateTime? _backgroundedAt;
  int _externalAuthDepth = 0;
  DateTime? _externalAuthUntil;
  DateTime? _ignoreLifecycleUntil;

  static void markInteractiveLogin() {
    if (!Get.isRegistered<AppLockController>()) return;
    Get.find<AppLockController>().unlockAfterInteractiveLogin();
  }

  static void noteRouteChange() {
    if (!Get.isRegistered<AppLockController>()) return;
    Get.find<AppLockController>().onRouteChanged();
  }

  static Future<bool> confirmSensitiveAction({required String reason}) async {
    if (kIsWeb) return true;
    if (!Get.isRegistered<AppLockController>()) return true;
    return Get.find<AppLockController>()._confirm(reason);
  }

  /// Wallet-client / SFSafariView / Web3Auth leave the Flutter view.
  /// Returning from that must not re-lock — Face ID already confirmed the action.
  static void beginExternalAuthSession() {
    if (!Get.isRegistered<AppLockController>()) return;
    Get.find<AppLockController>()._beginExternalAuthSession();
  }

  static void endExternalAuthSession() {
    if (!Get.isRegistered<AppLockController>()) return;
    Get.find<AppLockController>()._endExternalAuthSession();
  }

  void unlockAfterInteractiveLogin() {
    isUnlocked.value = true;
    _backgroundedAt = null;
  }

  void resetOnLogout() {
    isUnlocked.value = false;
    isAuthenticating.value = false;
    _backgroundedAt = null;
    _externalAuthDepth = 0;
    _externalAuthUntil = null;
    _ignoreLifecycleUntil = null;
  }

  void onRouteChanged() {
    // First-app attach builds from a Timer while schedulerPhase is still idle,
    // so never bump Obx listeners synchronously from routingCallback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      routeEpoch.value++;
    });
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  bool get _inExternalAuthSession {
    if (_externalAuthDepth <= 0) return false;
    final until = _externalAuthUntil;
    if (until != null && DateTime.now().isAfter(until)) {
      _externalAuthDepth = 0;
      _externalAuthUntil = null;
      return false;
    }
    return true;
  }

  bool get _shouldIgnoreLifecycle {
    if (isAuthenticating.value) return true;
    final ignoreUntil = _ignoreLifecycleUntil;
    if (ignoreUntil != null && DateTime.now().isBefore(ignoreUntil)) {
      return true;
    }
    return _inExternalAuthSession;
  }

  void _beginExternalAuthSession() {
    _externalAuthDepth++;
    _externalAuthUntil = DateTime.now().add(_externalAuthTimeout);
    _backgroundedAt = null;
  }

  void _endExternalAuthSession() {
    if (_externalAuthDepth > 0) _externalAuthDepth--;
    if (_externalAuthDepth == 0) {
      _externalAuthUntil = null;
    }
    _backgroundedAt = null;
  }

  void _absorbAuthLifecycle() {
    _backgroundedAt = null;
    _ignoreLifecycleUntil = DateTime.now().add(_postAuthLifecycleGrace);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (_shouldIgnoreLifecycle) {
      if (state == AppLifecycleState.resumed) {
        _backgroundedAt = null;
      }
      return;
    }

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _backgroundedAt ??= DateTime.now();
        break;
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (!isUnlocked.value) return;
        if (backgroundedAt == null) return;
        if (DateTime.now().difference(backgroundedAt) >= gracePeriod) {
          isUnlocked.value = false;
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<DeviceAuthResult> unlock({required String reason}) async {
    final result = await _authenticate(reason);
    if (result == DeviceAuthResult.success) {
      isUnlocked.value = true;
      _absorbAuthLifecycle();
    }
    return result;
  }

  Future<DeviceAuthResult> peekAvailability() async {
    if (kIsWeb) return DeviceAuthResult.success;
    final supported = await _auth.isSupportedOnThisPlatform;
    return supported
        ? DeviceAuthResult.success
        : DeviceAuthResult.unavailable;
  }

  Future<bool> _confirm(String reason) async {
    final result = await _authenticate(reason);
    if (result == DeviceAuthResult.success) {
      isUnlocked.value = true;
      _absorbAuthLifecycle();
      return true;
    }
    if (result == DeviceAuthResult.failed ||
        result == DeviceAuthResult.lockedOut ||
        result == DeviceAuthResult.unavailable) {
      unawaited(SbFeedback.error());
    }
    return false;
  }

  Future<DeviceAuthResult> _authenticate(String reason) async {
    if (kIsWeb) return DeviceAuthResult.success;
    if (isAuthenticating.value) return DeviceAuthResult.canceled;

    isAuthenticating.value = true;
    try {
      return await _auth.authenticate(reason: reason);
    } finally {
      isAuthenticating.value = false;
    }
  }
}
