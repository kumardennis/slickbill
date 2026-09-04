import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:slickbill/services/biometric_auth_service.dart';

class AppLockController extends GetxController with WidgetsBindingObserver {
  static const gracePeriod = Duration(seconds: 12);

  final BiometricAuthService _auth = BiometricAuthService();

  final isUnlocked = false.obs;
  final isAuthenticating = false.obs;
  final routeEpoch = 0.obs;

  DateTime? _backgroundedAt;

  static void markInteractiveLogin() {
    if (!Get.isRegistered<AppLockController>()) return;
    Get.find<AppLockController>().unlockAfterInteractiveLogin();
  }

  static void noteRouteChange() {
    if (!Get.isRegistered<AppLockController>()) return;
    Get.find<AppLockController>().routeEpoch.value++;
  }

  static Future<bool> confirmSensitiveAction({required String reason}) async {
    if (kIsWeb) return true;
    if (!Get.isRegistered<AppLockController>()) return true;
    return Get.find<AppLockController>()._confirm(reason);
  }

  void unlockAfterInteractiveLogin() {
    isUnlocked.value = true;
    _backgroundedAt = null;
  }

  void resetOnLogout() {
    isUnlocked.value = false;
    isAuthenticating.value = false;
    _backgroundedAt = null;
  }

  void onRouteChanged() => routeEpoch.value++;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    if (isAuthenticating.value) return;

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
      _backgroundedAt = null;
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
    return result == DeviceAuthResult.success;
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
