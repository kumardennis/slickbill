import 'dart:async';

import 'package:get/get.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/models/user_model.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';

enum PaymentSetupStep {
  connectWallet,
  connectMonerium,
  reconnectMonerium,
  complete,
}

class PaymentSetupController extends GetxController {
  final step = PaymentSetupStep.connectWallet.obs;
  final hasWallet = false.obs;
  final hasMoneriumSession = false.obs;
  final isAddressLinked = false.obs;
  final hasMoneriumIban = false.obs;
  final isRefreshing = false.obs;

  Worker? _userWorker;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<UserController>()) {
      _userWorker = ever(Get.find<UserController>().user, (_) {
        refresh();
      });
    }
    refresh();
  }

  @override
  void onClose() {
    _userWorker?.dispose();
    super.onClose();
  }

  static bool userHasMoneriumIban(ClientUserModel user) {
    final primaryBank = user.bankName?.trim().toLowerCase() ?? '';
    if (primaryBank.contains('monerium')) {
      return true;
    }

    final accounts = user.ibans;
    if (accounts == null || accounts.isEmpty) {
      return false;
    }

    return accounts.any(
      (account) => account.bankName.trim().toLowerCase().contains('monerium'),
    );
  }

  static String resolveMoneriumUserId(ClientUserModel user) {
    final privateUserId = user.privateUserId;
    if (privateUserId != null && privateUserId > 0) {
      return privateUserId.toString();
    }
    return user.id.toString();
  }

  Future<void> refresh() async {
    isRefreshing.value = true;
    String userId = '0';
    String? trackAddress;
    try {
      final userController = Get.find<UserController>();
      final user = userController.user.value;
      final address = user.metamaskWalletAddress?.trim();
      trackAddress = (address != null && address.isNotEmpty)
          ? address
          : user.cdpWalletId?.trim();
      final walletReady = address != null && address.isNotEmpty;
      final ibanReady = userHasMoneriumIban(user);
      userId = resolveMoneriumUserId(user);
      final balanceReady = userId.isNotEmpty && userId != '0'
          ? await MoneriumService.isBalanceConfirmedFlag(userId: userId)
          : false;

      hasWallet.value = walletReady;
      hasMoneriumIban.value = ibanReady || balanceReady;

      if (!walletReady) {
        hasMoneriumSession.value = false;
        isAddressLinked.value = false;
        step.value = PaymentSetupStep.connectWallet;
        return;
      }

      final sessionReady = userId.isNotEmpty && userId != '0'
          ? await MoneriumService.hasActiveSession(userId: userId)
          : false;
      final linkedReady = userId.isNotEmpty && userId != '0'
          ? await MoneriumService.isAddressLinkedFlag(userId: userId)
          : false;

      hasMoneriumSession.value = sessionReady;
      isAddressLinked.value = linkedReady || ibanReady || balanceReady;

      if (ibanReady || balanceReady) {
        step.value = sessionReady
            ? PaymentSetupStep.complete
            : PaymentSetupStep.reconnectMonerium;
        return;
      }

      step.value = PaymentSetupStep.connectMonerium;
    } finally {
      isRefreshing.value = false;
    }

    if (trackAddress != null &&
        trackAddress.isNotEmpty &&
        userId.isNotEmpty &&
        userId != '0') {
      unawaited(
        MoneriumService.registerWalletForTracking(
          userId: userId,
          walletAddress: trackAddress,
        ),
      );
    }
  }

  Future<void> markMoneriumConnected() async {
    hasMoneriumSession.value = true;
    if (step.value == PaymentSetupStep.connectWallet) {
      step.value = PaymentSetupStep.connectMonerium;
    }
    await refresh();
  }

  Future<void> markAddressLinked({required String userId}) async {
    await MoneriumService.setAddressLinked(userId: userId, linked: true);
    isAddressLinked.value = true;
    hasMoneriumSession.value = true;
    await refresh();
  }

  Future<void> markIbanReady() async {
    hasMoneriumIban.value = true;
    isAddressLinked.value = true;
    hasMoneriumSession.value = true;
    step.value = PaymentSetupStep.complete;
    await refresh();
  }

  /// Getting a Monerium balance proves the account is fully connected.
  Future<void> markCompleteFromBalance({required String userId}) async {
    await MoneriumService.setBalanceConfirmed(userId: userId, confirmed: true);
    await MoneriumService.setAddressLinked(userId: userId, linked: true);
    hasMoneriumIban.value = true;
    isAddressLinked.value = true;
    hasMoneriumSession.value = true;
    step.value = PaymentSetupStep.complete;
    await refresh();
  }
}
