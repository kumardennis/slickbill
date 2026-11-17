import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/models/user_model.dart';
import 'package:slickbill/feature_auth/services/metamask_wallet_service.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/payment_setup_controller.dart';
import 'package:slickbill/feature_dashboard/screens/profile.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';

/// After Monerium OAuth the Flutter web tab reloads, so link/IBAN must resume here.
Future<void> completeWebMoneriumOAuthReturnIfNeeded() async {
  if (!kIsWeb) return;

  final shouldResume =
      await MoneriumService.consumeWebOAuthCallbackIfPresent();
  if (!shouldResume) return;

  if (!Get.isRegistered<UserController>()) return;
  final userController = Get.find<UserController>();
  for (var attempt = 0; attempt < 5; attempt++) {
    if (userController.user.value.id > 0) break;
    await userController.loadUserData();
    if (userController.user.value.id > 0) break;
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  if (userController.user.value.id <= 0) return;

  final user = userController.user.value;
  final userId = PaymentSetupController.resolveMoneriumUserId(user);
  final address = user.metamaskWalletAddress?.trim() ?? '';
  if (userId.isEmpty) {
    await MoneriumService.clearWebConnectPending();
    return;
  }
  if (!await MoneriumService.hasWebConnectPending(userId: userId)) {
    await MoneriumService.clearWebConnectPending();
    return;
  }

  try {
    final hasSession = await MoneriumService.hasActiveSession(userId: userId);
    if (!hasSession) {
      await MoneriumService.clearWebConnectPending();
      throw Exception('Monerium session was not established.');
    }

    if (address.isEmpty) {
      await MoneriumService.clearWebConnectPending();
      Get.snackbar(
        'Wallet required',
        'Connect your wallet, then tap Reconnect Monerium again.',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final linkedResponse = await MoneriumService.getLinkedAddresses(
      userId: userId,
      address: address,
    );
    var linked = linkedResponse['linked'] == true;
    final existingSignature =
        Uri.base.queryParameters['signature']?.trim() ?? '';

    if (!linked && existingSignature.isNotEmpty) {
      final linkResponse = await MoneriumService.linkWallet(
        userId: userId,
        address: address,
        message: MetamaskWalletService.moneriumOwnershipMessage,
        signature: existingSignature,
      );
      linked = MoneriumService.isWalletLinkSuccessful(linkResponse);
    } else if (!linked) {
      final signature =
          await MetamaskWalletService.signAddressOwnershipMessage(
        address: address,
        preview: const WalletClientPaymentPreview(kind: 'link'),
        userId: userId,
      );
      final linkResponse = await MoneriumService.linkWallet(
        userId: userId,
        address: address,
        message: MetamaskWalletService.moneriumOwnershipMessage,
        signature: signature,
      );
      linked = MoneriumService.isWalletLinkSuccessful(linkResponse);
    }

    var ibansResponse = await MoneriumService.getIbans(
      userId: userId,
      address: address,
    );
    var ibans = MoneriumService.filterIbansForWallet(
      ibans: MoneriumService.extractIbansFromResponse(ibansResponse),
      walletAddress: address,
    );

    if (ibans.isEmpty && linked) {
      final ensureResponse = await MoneriumService.ensureIbanForWallet(
        userId: userId,
        address: address,
      );
      ibansResponse = await MoneriumService.getIbans(
        userId: userId,
        address: address,
      );
      ibans = MoneriumService.filterIbansForWallet(
        ibans: MoneriumService.extractIbansFromResponse(ibansResponse),
        walletAddress: address,
      );
      if (ibans.isEmpty) {
        ibans = MoneriumService.filterIbansForWallet(
          ibans: MoneriumService.extractIbansFromResponse(ensureResponse),
          walletAddress: address,
        );
      }
    }

    if (Get.isRegistered<PaymentSetupController>()) {
      final setup = Get.find<PaymentSetupController>();
      if (MoneriumService.hasIssuedIban(ibans)) {
        await setup.markIbanReady();
      } else if (linked) {
        await setup.markAddressLinked(userId: userId);
      } else {
        await setup.markMoneriumConnected();
      }
    }

    if (MoneriumService.hasIssuedIban(ibans)) {
      final accounts = <BankAccount>[];
      for (final row in ibans) {
        final iban = MoneriumService.issuedIbanFromRow(row);
        if (iban == null) continue;
        final holder = row is Map ? row['name']?.toString() : null;
        accounts.add(
          BankAccount(
            iban: iban,
            bankName: 'Monerium (LHV)',
            bankAccountName: holder,
            isPrimary: false,
          ),
        );
      }
      if (accounts.isNotEmpty) {
        await userController.upsertIbansJson(accounts);
      }
    }

    await MoneriumService.clearWebConnectPending();

    Get.snackbar(
      MoneriumService.hasIssuedIban(ibans)
          ? 'Payments ready'
          : (linked ? 'KYC pending' : 'Monerium connected'),
      MoneriumService.hasIssuedIban(ibans)
          ? 'Your Monerium IBAN is set up.'
          : (linked
              ? 'Finish Monerium KYC, then tap Reconnect. The IBAN is not issued yet.'
              : 'Sign in succeeded. Complete Monerium KYC, then tap Reconnect again.'),
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
    );
  } catch (error) {
    if (MetamaskWalletService.isCancelled(error)) {
      await MoneriumService.clearWebConnectPending();
      Get.snackbar(
        'Monerium',
        'Sign the wallet ownership message to finish linking.',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
      return;
    }
    await MoneriumService.clearWebConnectPending();
    Get.snackbar(
      'Monerium',
      _moneriumLinkErrorMessage(error),
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 6),
    );
  }
}

String _moneriumLinkErrorMessage(Object error) {
  if (MoneriumService.isAlreadyLinkedElsewhereError(error)) {
    return 'This wallet is still registered on another Monerium profile. It is not on this login, so it cannot be attached here. Use a different wallet, or unlink it from that other Monerium account.';
  }
  return error.toString();
}

/// After a web wallet redirect, finish pay/withdraw or Monerium IBAN linking.
Future<void> completeWebWalletReturn(WebWalletCallback? callback) async {
  if (callback == null) return;

  final signature = callback.signature?.trim() ?? '';
  if (signature.isNotEmpty &&
      (callback.kind == 'pay' || callback.kind == 'withdraw')) {
    await _completeWebPaymentReturn(callback);
    return;
  }

  if (!callback.shouldFinishIbanLink) return;

  final address = callback.address?.trim() ?? '';
  if (address.isEmpty || signature.isEmpty) return;
  if (!Get.isRegistered<UserController>()) return;

  final userController = Get.find<UserController>();
  if (userController.user.value.id <= 0) {
    await userController.loadUserData();
  }
  if (userController.user.value.id <= 0) return;

  final user = userController.user.value;
  final userId = PaymentSetupController.resolveMoneriumUserId(user);
  if (userId.isEmpty) return;

  await MoneriumService.clearWebConnectPending();

  try {
    await MoneriumService.linkWallet(
      userId: userId,
      address: address,
      message: MetamaskWalletService.moneriumOwnershipMessage,
      signature: signature,
    );

    var ibansResponse = await MoneriumService.getIbans(
      userId: userId,
      address: address,
    );
    var ibans = MoneriumService.filterIbansForWallet(
      ibans: MoneriumService.extractIbansFromResponse(ibansResponse),
      walletAddress: address,
    );

    if (ibans.isEmpty) {
      final ensureResponse = await MoneriumService.ensureIbanForWallet(
        userId: userId,
        address: address,
      );
      ibansResponse = await MoneriumService.getIbans(
        userId: userId,
        address: address,
      );
      ibans = MoneriumService.filterIbansForWallet(
        ibans: MoneriumService.extractIbansFromResponse(ibansResponse),
        walletAddress: address,
      );
      if (ibans.isEmpty) {
        ibans = MoneriumService.filterIbansForWallet(
          ibans: MoneriumService.extractIbansFromResponse(ensureResponse),
          walletAddress: address,
        );
      }
    }

    if (Get.isRegistered<PaymentSetupController>()) {
      final setup = Get.find<PaymentSetupController>();
      if (MoneriumService.hasIssuedIban(ibans)) {
        await setup.markIbanReady();
      } else {
        await setup.markAddressLinked(userId: userId);
      }
    }

    final accounts = <BankAccount>[];
    for (final row in ibans) {
      final iban = MoneriumService.issuedIbanFromRow(row);
      if (iban == null) continue;
      final holder = row is Map
          ? row['holderName']?.toString()
          : null;
      accounts.add(
        BankAccount(
          iban: iban,
          bankName: 'Monerium (LHV)',
          bankAccountName: holder,
          isPrimary: false,
        ),
      );
    }
    if (accounts.isNotEmpty) {
      await userController.upsertIbansJson(accounts);
    }

    Get.snackbar(
      MoneriumService.hasIssuedIban(ibans) ? 'IBAN ready' : 'KYC pending',
      MoneriumService.hasIssuedIban(ibans)
          ? 'Your Monerium IBAN is now available in Profile.'
          : 'Finish Monerium KYC, then tap Reconnect. The IBAN is not issued yet.',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
    );

    Get.to(() => const Profile());
  } catch (error) {
    Get.snackbar(
      'Monerium',
      _moneriumLinkErrorMessage(error),
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 6),
    );
  }
}

Future<void> _completeWebPaymentReturn(WebWalletCallback callback) async {
  if (!Get.isRegistered<UserController>()) return;
  final userController = Get.find<UserController>();
  if (userController.user.value.id <= 0) {
    await userController.loadUserData();
  }
  if (userController.user.value.id <= 0) return;

  final signature = callback.signature!.trim();

  try {
    final response = await MoneriumService.submitPendingWebPayment(
      signature: signature,
      address: callback.address,
    );

    if (response == null) {
      Get.snackbar(
        callback.kind == 'withdraw' ? 'Withdrawal' : 'Payment',
        'This transfer was already submitted.',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final orderId = MoneriumService.extractOrderId(response);
    final txHash = MoneriumService.extractOrderTxHash(response);
    final invoiceIds = <int>{};
    void addInvoiceId(dynamic raw) {
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null && parsed > 0) invoiceIds.add(parsed);
    }

    addInvoiceId(response['invoiceId']);
    final rawIds = response['invoiceIds'];
    if (rawIds is List) {
      for (final id in rawIds) {
        addInvoiceId(id);
      }
    }

    if (Get.isRegistered<DigitalInvoiceController>()) {
      final invoices = Get.find<DigitalInvoiceController>();
      for (final invoiceId in invoiceIds) {
        if (orderId != null && orderId.isNotEmpty) {
          await MoneriumService.savePendingOrderForInvoice(
            invoiceId: invoiceId,
            orderId: orderId,
          );
          await invoices.updateMoneriumOrderIdForInvoice(invoiceId, orderId);
        }
        if (txHash != null && txHash.isNotEmpty) {
          await invoices.updateTxHashForInvoice(invoiceId, txHash);
        }
        final latest =
            await invoices.getInvoiceById(invoiceId, silent: true);
        final latestStatus = (latest?.status ?? '').trim().toUpperCase();
        if (latestStatus != 'PAID') {
          await ReceivedInvoicesClass().updateInvoiceStatus(
            invoiceId,
            'PROCESSING',
            silent: true,
          );
        }
      }
      if (invoiceIds.isNotEmpty) {
        invoices.requestReceivedListRefresh();
        invoices.requestSentListRefresh();
      }
    }

    Get.snackbar(
      callback.kind == 'withdraw' ? 'Withdrawal sent' : 'Payment sent',
      callback.kind == 'withdraw'
          ? 'Your withdrawal is processing.'
          : 'Your payment is processing. You can follow it on Bills.',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
    );
  } catch (error) {
    Get.snackbar(
      callback.kind == 'withdraw' ? 'Withdrawal' : 'Payment',
      error.toString(),
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }
}
