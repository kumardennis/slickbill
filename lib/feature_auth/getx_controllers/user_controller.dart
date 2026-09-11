import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slickbill/core/services/push_notification_service.dart';
import 'package:slickbill/feature_auth/repos/user_repo.dart';
import 'package:slickbill/feature_auth/getx_controllers/app_lock_controller.dart';
import 'package:slickbill/feature_auth/services/google_auth_service.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
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
  int _remoteProfileEpoch = 0;
  StreamSubscription<AuthState>? _authSub;
  Future<bool>? _refreshInFlight;

  static const _refreshSkewSeconds = 90;

  /// Prefer the live Supabase session JWT over the cached user copy.
  String get accessToken {
    final live = supabase.auth.currentSession?.accessToken.trim() ?? '';
    if (live.isNotEmpty) return live;
    return user.value.accessToken;
  }

  int beginRemoteUserLoad() => ++_remoteProfileEpoch;

  @override
  void onInit() {
    super.onInit();
    _authSub = supabase.auth.onAuthStateChange.listen(_onAuthStateChange);
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }

  void _onAuthStateChange(AuthState data) {
    final session = data.session;
    if (session == null) return;
    if (data.event == AuthChangeEvent.tokenRefreshed ||
        data.event == AuthChangeEvent.signedIn ||
        data.event == AuthChangeEvent.userUpdated) {
      _syncAccessToken(session);
    }
  }

  loadUser(ClientUserModel updatedUser, {int? epoch}) {
    if (epoch != null && epoch != _remoteProfileEpoch) {
      print(
          'Ignoring stale user profile load epoch=$epoch current=$_remoteProfileEpoch');
      return;
    }

    user.value = updatedUser;
    saveUserData();

    if (updatedUser.id > 0) {
      unawaited(PushNotificationService.loginUser());
    }
  }

  /// Re-read the signed-in profile from Postgres. Local cache is not used.
  Future<bool> reloadFromDatabase() async {
    final session = supabase.auth.currentSession;
    if (session == null) return false;

    return SupabaseAuthManger().loadFreshUser(
      session.user.id,
      session.accessToken,
    );
  }

  bool _needsRefresh(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    return expiresAt <= now + _refreshSkewSeconds;
  }

  bool _isFatalAuthError(Object error) {
    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();
      if (code.contains('refresh_token')) return true;
      if (message.contains('invalid refresh token')) return true;
      if (message.contains('refresh token not found')) return true;
      if (message.contains('session not found')) return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('invalid refresh token') ||
        text.contains('refresh_token_not_found');
  }

  void _syncAccessToken(Session session) {
    if (user.value.id <= 0) return;
    if (user.value.accessToken == session.accessToken) return;
    user.value = user.value.copyWith(accessToken: session.accessToken);
    unawaited(saveUserData());
  }

  /// Refresh the JWT if it is expired or about to expire.
  /// Does not log the user out on a transient network failure.
  Future<bool> ensureFreshSession({bool force = false}) async {
    if (_refreshInFlight != null) return _refreshInFlight!;
    final future = _ensureFreshSession(force: force);
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _ensureFreshSession({required bool force}) async {
    try {
      var session = supabase.auth.currentSession;
      if (session == null) return false;

      if (!force && !_needsRefresh(session)) {
        _syncAccessToken(session);
        return true;
      }

      print('Refreshing Supabase session...');
      final response = await supabase.auth.refreshSession();
      session = response.session ?? supabase.auth.currentSession;
      if (session == null) {
        print('Session refresh returned no session');
        return false;
      }
      _syncAccessToken(session);
      print('Session refreshed successfully');
      return true;
    } catch (e) {
      print('Error refreshing session: $e');
      if (_isFatalAuthError(e)) {
        await forceLogout();
        return false;
      }
      final session = supabase.auth.currentSession;
      if (session != null) {
        _syncAccessToken(session);
        return true;
      }
      return false;
    }
  }

  Future<bool> refreshSessionIfNeeded() => ensureFreshSession();

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
      final refreshed = await ensureFreshSession();
      if (!refreshed || supabase.auth.currentSession == null) {
        return false;
      }

      return await reloadFromDatabase();
    } catch (e) {
      print('Error loading user data: $e');
      return false;
    }
  }

  /// Loads the session into [user], or sends the guest to sign-in.
  Future<bool> ensureSignedInOrRedirect() async {
    if (user.value.id > 0) return true;

    await loadUserData();
    if (user.value.id > 0) return true;

    final route = Get.currentRoute;
    if (route == '/sign-in' || route.startsWith('/sign-in')) {
      return false;
    }

    Get.offAllNamed('/sign-in');
    return false;
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

      beginRemoteUserLoad();
      final trimmedPublicName = publicName?.trim();
      final safePublicName =
          (trimmedPublicName != null && trimmedPublicName.contains('@'))
              ? null
              : trimmedPublicName;
      final response = await _userRepo.updateBusinessProfile(
        privateUserId: privateUserId,
        isBusiness: isBusiness,
        publicName: safePublicName,
      );

      if (response == null) {
        return false;
      }

      await reloadFromDatabase();
      user.value = user.value.copyWith(
        isBusiness: ClientUserModel.isBusinessFromDb(response['isBusiness']),
        publicName: response['publicName'] as String? ?? user.value.publicName,
      );
      beginRemoteUserLoad();
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
    }
  }

  Future<void> _awaitSafely(Future<void> future, {String label = 'task'}) async {
    try {
      await future.timeout(const Duration(seconds: 4));
    } catch (e) {
      print('Sign-out $label skipped: $e');
    }
  }

  Future<void> forceLogout() async {
    await _awaitSafely(
      PushNotificationService.logoutUser(),
      label: 'push logout',
    );
    await _awaitSafely(
      supabase.auth.signOut(
        scope: kIsWeb ? SignOutScope.local : SignOutScope.global,
      ),
      label: 'supabase signOut',
    );
    await clearUserData();
    while (Get.isDialogOpen ?? false) {
      Get.back();
    }
    Get.offAllNamed('/sign-in');
  }
}
