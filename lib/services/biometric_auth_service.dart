import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';

enum DeviceAuthResult {
  success,
  canceled,
  unavailable,
  lockedOut,
  failed,
}

class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get isSupportedOnThisPlatform async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<DeviceAuthResult> authenticate({
    required String reason,
  }) async {
    if (kIsWeb) return DeviceAuthResult.success;

    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return DeviceAuthResult.unavailable;

      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Unlock SlickBills',
            cancelButton: 'Cancel',
            biometricHint: '',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsButton: 'Settings',
            goToSettingsDescription:
                'Turn on Face ID or a device passcode to use SlickBills.',
            lockOut:
                'Too many attempts. Lock your phone and try again, or use your passcode.',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      return authenticated
          ? DeviceAuthResult.success
          : DeviceAuthResult.canceled;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'PasscodeNotSet':
        case 'NotSupported':
        case 'OtherOperatingSystem':
          return DeviceAuthResult.unavailable;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return DeviceAuthResult.lockedOut;
        case 'auth_in_progress':
          return DeviceAuthResult.canceled;
        default:
          return DeviceAuthResult.failed;
      }
    } catch (_) {
      return DeviceAuthResult.failed;
    }
  }
}
