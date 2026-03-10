import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';

class BiometricAuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    
    try {
      final isDeviceSupported = await _auth.isDeviceSupported();
      print('🔍 Device supported: $isDeviceSupported');
      
      if (!isDeviceSupported) return false;
      
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      print('🔍 Can check biometrics: $canCheckBiometrics');
      
      final availableBiometrics = await _auth.getAvailableBiometrics();
      print('🔍 Available biometrics: $availableBiometrics');
      
      return canCheckBiometrics && availableBiometrics.isNotEmpty;
    } catch (e) {
      print('❌ Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate using biometrics
  Future<bool> authenticateWithBiometrics({
    required String reason,
  }) async {
    if (kIsWeb) {
      print('⚠️ Biometric not available on web');
      return true; // Allow payment on web
    }

    try {
      // ✅ Check if device supports biometrics
      final isDeviceSupported = await _auth.isDeviceSupported();
      print('🔍 Device supports biometric: $isDeviceSupported');

      if (!isDeviceSupported) {
        print('⚠️ Device does not support biometric, allowing payment');
        return true; // Allow payment without biometric
      }

      // ✅ Check if biometrics can be used
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      print('🔍 Can check biometrics: $canCheckBiometrics');

      // ✅ Get available biometrics
      final availableBiometrics = await _auth.getAvailableBiometrics();
      print('🔍 Available biometrics: $availableBiometrics');

      if (availableBiometrics.isEmpty) {
        print('⚠️ No biometric methods enrolled, allowing payment');
        return true; // Allow payment without biometric
      }

      // ✅ Attempt biometric authentication
      print('🔐 Attempting biometric authentication...');
      
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Biometric Authentication Required',
            cancelButton: 'Cancel',
            biometricHint: '',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
            goToSettingsButton: 'Settings',
            goToSettingsDescription: 'Please set up biometric authentication.',
            lockOut:
                'Biometric authentication is disabled. Please lock and unlock your screen to enable it.',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // ✅ Allow PIN/Password fallback
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      print(authenticated ? '✅ Authentication successful' : '❌ Authentication cancelled');
      return authenticated;
      
    } on PlatformException catch (e) {
      print('❌ Platform exception: ${e.code} - ${e.message}');
      
      // Handle specific error codes
      switch (e.code) {
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'PasscodeNotSet':
          print('⚠️ Biometric not set up, allowing payment');
          return true;
        
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          print('🔒 Too many failed attempts');
          return false;
        
        case 'OtherOperatingSystem':
        case 'NotSupported':
          print('⚠️ Not supported on this device, allowing payment');
          return true;
        
        default:
          print('⚠️ Unknown error (${e.code}), blocking payment for safety');
          return false;
      }
    } catch (e) {
      print('❌ Unexpected error: $e');
      return false; // Block payment on unexpected errors
    }
  }

  /// Get biometric type name for display
  String getBiometricTypeName(List<BiometricType> types) {
    if (types.isEmpty) return 'Biometric';

    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    }

    return 'Biometric';
  }
}
