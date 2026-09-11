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

  try {
    await MoneriumService.linkWallet(
      userId: userId,
      address: address,
      message: MetamaskWalletService.moneriumOwnershipMessage,
      signature: signature,
    );

    var ibansResponse = await MoneriumService.getIbans(userId: userId);
    var ibans = MoneriumService.extractIbansFromResponse(ibansResponse);

    if (ibans.isEmpty) {
      await MoneriumService.requestIban(
        userId: userId,
        address: address,
      );
      ibansResponse = await MoneriumService.getIbans(userId: userId);
      ibans = MoneriumService.extractIbansFromResponse(ibansResponse);
    }

    if (Get.isRegistered<PaymentSetupController>()) {
      final setup = Get.find<PaymentSetupController>();
      if (ibans.isNotEmpty) {
        await setup.markIbanReady();
      } else {
        await setup.markAddressLinked(userId: userId);
      }
    }

    final accounts = <BankAccount>[];
    for (final row in ibans) {
      if (row is! Map) continue;
      final iban = row['iban']?.toString().trim() ??
          row['ibanNumber']?.toString().trim() ??
          '';
      if (iban.isEmpty) continue;
      accounts.add(
        BankAccount(
          iban: iban,
          bankName: 'Monerium (LHV)',
          bankAccountName: row['holderName']?.toString(),
          isPrimary: false,
        ),
      );
    }
    if (accounts.isNotEmpty) {
      await userController.upsertIbansJson(accounts);
    }

    Get.snackbar(
      ibans.isNotEmpty ? 'IBAN ready' : 'Wallet linked',
      ibans.isNotEmpty
          ? 'Your Monerium IBAN is now available in Profile.'
          : 'Wallet is linked. Open Profile if the IBAN is still provisioning.',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 4),
    );

    Get.to(() => const Profile());
  } catch (error) {
    Get.snackbar(
      'Monerium',
      error.toString(),
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red.shade700,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
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
    final invoiceId = int.tryParse(response['invoiceId']?.toString() ?? '');

    if (Get.isRegistered<DigitalInvoiceController>()) {
      final invoices = Get.find<DigitalInvoiceController>();
      if (invoiceId != null && invoiceId > 0) {
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
