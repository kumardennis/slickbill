import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slickbill/core/services/push_notification_service.dart';
import 'package:slickbill/feature_auth/repos/user_repo.dart';
import 'package:slickbill/feature_auth/getx_controllers/app_lock_controller.dart';
import 'package:slickbill/feature_auth/screens/sign_in.dart';
import 'package:slickbill/feature_auth/services/google_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class UserController extends GetxController {
  final supabase = Supabase.instance.client;
  final UserRepo _userRepo = UserRepo();
  var user = ClientUserModel(
    id: 0,
    username: '',
    email: '',
    authUserId: '',
    accessToken: '',
    isPrivate: true,
    firstName: '',
    lastName: '',
    cdpWalletId: null,
    metamaskWalletAddress: null,
  ).obs;

  final GoogleAuthService _googleAuthService = GoogleAuthService();

  loadUser(ClientUserModel updatedUser) {
    user.value = updatedUser;
    saveUserData();

    if (updatedUser.id > 0) {
      unawaited(PushNotificationService.loginUser());
    }
  }

  bool _isTokenExpired(Session session) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    return session.expiresAt != null && session.expiresAt! <= now;
  }

  Future<bool> refreshSessionIfNeeded() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return false;

      if (_isTokenExpired(session)) {
        print('Token expired, attempting refresh...');
        final response = await supabase.auth.refreshSession();

        if (response.session != null) {
          // Update the access token in user model
          user.value = user.value.copyWith(
            accessToken: response.session!.accessToken,
            cdpWalletId: user.value.cdpWalletId,
          );
          await saveUserData();
          print('Session refreshed successfully');
          return true;
        } else {
          print('Failed to refresh session');
          await clearUserData();
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error refreshing session: $e');
      await clearUserData();
      return false;
    }
  }

  Future<void> saveUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.value.toJson());
      await prefs.setString('user_data', userJson);
      print('User data saved to local storage');
    } catch (e) {
      print('Error saving user data: $e');
    }
  }

  Future<bool> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');

      if (userJson != null) {
        final userData = jsonDecode(userJson);
        user.value = ClientUserModel.fromJson(userData);

        // Validate the session
        final session = supabase.auth.currentSession;
        if (session != null && !_isTokenExpired(session)) {
          print('User data loaded and session is valid');
          return true;
        } else {
          print('Session is expired or invalid');
          await clearUserData();
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error loading user data: $e');
      await clearUserData();
      return false;
    }
  }

  Future<bool> updateCdpWalletAddress(
      String walletAddress, String cdpUserId) async {
    try {
      print(
          'Updating CDP wallet address: $walletAddress $cdpUserId for user ID: ${user.value.id}');

      final response = await _userRepo.updateCdpWalletId(
        userId: user.value.id,
        cdpWalletId: walletAddress,
        cdpUserId: cdpUserId,
      );

      if (response != null) {
        // Update local user model
        user.value = user.value.copyWith(cdpWalletId: walletAddress);
        await saveUserData();

        print('✅ CDP wallet address updated successfully');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error updating CDP wallet address: $e');
      return false;
    }
  }

  Future<String?> getCdpWalletAddress() async {
    try {
      final walletId = await _userRepo.getCdpWalletId(user.value.id);

      if (walletId != null) {
        // Update local user model
        user.value = user.value.copyWith(cdpWalletId: walletId);
        await saveUserData();
      }

      return walletId;
    } catch (e) {
      print('❌ Error fetching CDP wallet address: $e');
      return null;
    }
  }

  Future<bool> updateMetamaskWalletAddress(String walletAddress) async {
    try {
      if (user.value.id <= 0) {
        return false;
      }

      final response = await _userRepo.updateMetamaskWalletAddress(
        userId: user.value.id,
        walletAddress: walletAddress,
      );

      if (response != null) {
        user.value = user.value.copyWith(metamaskWalletAddress: walletAddress);
        await saveUserData();
        return true;
      }

      return false;
    } catch (e) {
      print('Error updating MetaMask wallet address: $e');
      return false;
    }
  }

  Future<String?> getMetamaskWalletAddress() async {
    try {
      if (user.value.id <= 0) {
        return null;
      }

      final address = await _userRepo.getMetamaskWalletAddress(user.value.id);
      if (address != null) {
        user.value = user.value.copyWith(metamaskWalletAddress: address);
        await saveUserData();
      }
      return address;
    } catch (e) {
      print('Error fetching MetaMask wallet address: $e');
      return null;
    }
  }

  Future<bool> updatePrimaryIbanColumn({
    required String iban,
    String? bankName,
    String? bankAccountName,
  }) async {
    try {
      if (user.value.privateUserId == null) {
        return false;
      }

      Map<String, dynamic>? response;
      try {
        response = await _userRepo.updatePrimaryIbanColumn(
          privateUserId: user.value.privateUserId!,
          iban: iban,
          bankName: bankName,
          bankAccountName: bankAccountName,
        );
      } catch (e) {
        final supportsBankName = bankName != null && bankName.trim().isNotEmpty;
        if (!supportsBankName) {
          rethrow;
        }

        print('Retrying primary iban update without bankName due error: $e');
        response = await _userRepo.updatePrimaryIbanColumn(
          privateUserId: user.value.privateUserId!,
          iban: iban,
          bankName: bankName,
          bankAccountName: bankAccountName,
          includeTopLevelBankName: false,
        );
      }

      if (response == null) {
        return false;
      }

      final trimmedBankName = bankName?.trim();
      final trimmedBankAccountName = bankAccountName?.trim();
      List<BankAccount>? parsedIbans;
      final responseIbans = response['ibans'];
      if (responseIbans is List) {
        parsedIbans = responseIbans
            .whereType<Map>()
            .map((row) => BankAccount.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false);
      }

      user.value = user.value.copyWith(
        iban: iban,
        ibans: parsedIbans ?? user.value.ibans,
        bankName: trimmedBankName != null && trimmedBankName.isNotEmpty
            ? trimmedBankName
            : user.value.bankName,
        bankAccountName:
            trimmedBankAccountName != null && trimmedBankAccountName.isNotEmpty
                ? trimmedBankAccountName
                : user.value.bankAccountName,
      );
      await saveUserData();
      return true;
    } catch (e) {
      print('Error updating primary iban column: $e');
      return false;
    }
  }

  Future<bool> upsertIbansJson(List<BankAccount> incomingIbans) async {
    try {
      final privateUserId = user.value.privateUserId;
      if (privateUserId == null) {
        return false;
      }

      if (incomingIbans.isEmpty) {
        return true;
      }

      final payload = incomingIbans.map((item) => item.toJson()).toList();
      final response = await _userRepo.upsertIbansJson(
        privateUserId: privateUserId,
        ibans: payload,
      );

      if (response == null) {
        return false;
      }

      List<BankAccount>? parsedIbans;
      final responseIbans = response['ibans'];
      if (responseIbans is List) {
        parsedIbans = responseIbans
            .whereType<Map>()
            .map((row) => BankAccount.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false);
      }

      BankAccount? primary;
      if (parsedIbans != null) {
        for (final account in parsedIbans) {
          if (account.isPrimary) {
            primary = account;
            break;
          }
        }
        primary ??= parsedIbans.isNotEmpty ? parsedIbans.first : null;
      }

      user.value = user.value.copyWith(
        ibans: parsedIbans ?? user.value.ibans,
        iban: primary?.iban ?? response['iban']?.toString() ?? user.value.iban,
        bankName: primary?.bankName.isNotEmpty == true
            ? primary!.bankName
            : (response['bankName']?.toString() ?? user.value.bankName),
        bankAccountName: primary?.bankAccountName?.trim().isNotEmpty == true
            ? primary!.bankAccountName
            : (response['bankAccountName']?.toString() ??
                user.value.bankAccountName),
      );
      await saveUserData();
      return true;
    } catch (e) {
      print('Error upserting ibans json: $e');
      return false;
    }
  }

  Future<bool> updateBusinessProfile({
    required bool isBusiness,
    String? publicName,
  }) async {
    try {
      final privateUserId = user.value.privateUserId;
      if (privateUserId == null) {
        return false;
      }

      final trimmedPublicName = publicName?.trim();
      final response = await _userRepo.updateBusinessProfile(
        privateUserId: privateUserId,
        isBusiness: isBusiness,
        publicName: trimmedPublicName,
      );

      if (response == null) {
        return false;
      }

      user.value = user.value.copyWith(
        isBusiness: isBusiness,
        publicName: trimmedPublicName ?? user.value.publicName,
      );
      await saveUserData();
      return true;
    } catch (e) {
      print('Error updating business profile: $e');
      return false;
    }
  }

  Future<void> clearUserData() async {
    try {
      if (Get.isRegistered<AppLockController>()) {
        Get.find<AppLockController>().resetOnLogout();
      }
      await _googleAuthService.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
      user.value = ClientUserModel(
        id: 0,
        username: '',
        email: '',
        authUserId: '',
        accessToken: '',
        isPrivate: true,
        firstName: '',
        lastName: '',
      );
      print('User data cleared');
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  Future<void> forceLogout() async {
    try {
      await PushNotificationService.logoutUser();
      await supabase.auth.signOut();
      await clearUserData();
      Get.offAll(() => SignIn());
    } catch (e) {
      print('Error during force logout: $e');
    }
  }
}
