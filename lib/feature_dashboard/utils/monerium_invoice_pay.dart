import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/core/services/app_analytics.dart';
import 'package:slickbill/core/services/invoice_toast_coordinator.dart';
import 'package:slickbill/feature_auth/getx_controllers/app_lock_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/services/metamask_wallet_service.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/payment_setup_controller.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/batch_pay_from_sender.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/services/sb_feedback.dart';

/// One Monerium redeem for one or more unpaid received invoices.
Future<bool> payMoneriumInvoices({
  required BuildContext context,
  required List<InvoiceModel> invoices,
  void Function(String phase)? onPhase,
  Future<void> Function()? onAfterInitiate,
}) async {
  final selected = [...invoices]..sort((a, b) => a.id.compareTo(b.id));
  final selectionErrorKey = BatchPayFromSender.selectionError(selected);
  if (selectionErrorKey != null) {
    Get.snackbar(
      'err_BatchCannotPayTogether'.tr,
      selectionErrorKey.tr,
      backgroundColor: Theme.of(context).colorScheme.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
    return false;
  }

  final seed = selected.first;
  final amount = BatchPayFromSender.sum(selected);
  final userController = Get.find<UserController>();
  final invoiceController = Get.find<DigitalInvoiceController>();
  final receivedInvoicesClass = ReceivedInvoicesClass();
  final user = userController.user.value;
  final moneriumUserId = PaymentSetupController.resolveMoneriumUserId(user);
  final email = user.email.trim();

  AppAnalytics.payStarted();

  final walletAddress = user.metamaskWalletAddress?.trim() ?? '';
  if (walletAddress.isEmpty) {
    Get.snackbar(
      'err_WalletNotConnected'.tr,
      'err_WalletNotConnectedMsg'.tr,
      backgroundColor: Theme.of(context).colorScheme.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
    AppAnalytics.payFailed(reason: 'missing_wallet');
    return false;
  }

  final destinationIban = BatchPayFromSender.normalizedPayIban(seed);
  if (destinationIban == null || destinationIban.isEmpty) {
    Get.snackbar(
      'err_IbanMissing'.tr,
      'err_IbanMissingMsg'.tr,
      backgroundColor: Theme.of(context).colorScheme.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
    AppAnalytics.payFailed(reason: 'missing_iban');
    return false;
  }

  if (email.isEmpty) {
    Get.snackbar(
      'err_EmailMissing'.tr,
      'err_EmailMissingMsg'.tr,
      backgroundColor: Theme.of(context).colorScheme.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
    AppAnalytics.payFailed(reason: 'missing_email');
    return false;
  }

  AppLockController.beginExternalAuthSession();
  unawaited(SbFeedback.medium());
  onPhase?.call('checkingBalance');
  try {
    try {
      await MoneriumService.ensureConnected(
        userId: moneriumUserId,
        email: email,
        onWillOpenLogin: () {
          Get.snackbar(
            'inf_ConnectingMonerium'.tr,
            'inf_ConnectingMoneriumMsg'.tr,
            backgroundColor: Theme.of(context).colorScheme.blue,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        },
      );
      if (Get.isRegistered<PaymentSetupController>()) {
        await Get.find<PaymentSetupController>().markMoneriumConnected();
      }
    } catch (error) {
      Get.snackbar(
        'err_MoneriumConnectFailed'.tr,
        'err_MoneriumConnectFailedMsg'.tr,
        backgroundColor: Theme.of(context).colorScheme.yellow,
        colorText: Colors.black,
        duration: const Duration(seconds: 4),
      );
      AppAnalytics.payFailed(reason: 'connect_failed');
      return false;
    }

    final balanceCheck = await MoneriumService.checkSufficientEur(
      userId: moneriumUserId,
      walletAddress: walletAddress,
      amount: amount,
    );
    if (!balanceCheck.sufficient) {
      Get.snackbar(
        balanceCheck.available == null
            ? 'hd_BalanceCheck'.tr
            : 'err_NotEnoughBalance'.tr,
        balanceCheck.message ?? 'err_NotEnoughBalanceMsg'.tr,
        backgroundColor: Theme.of(context).colorScheme.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      AppAnalytics.payFailed(reason: 'no_balance');
      return false;
    }

    onPhase?.call('updatingStatus');

    final countryCode = RegExp(r'^[A-Z]{2}').hasMatch(destinationIban)
        ? destinationIban.substring(0, 2)
        : 'EE';
    final nowUtc = DateTime.now().toUtc();
    final timestamp =
        '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}T${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')}Z';
    final orderMessage =
        'Send EUR ${amount.toStringAsFixed(2)} to $destinationIban at $timestamp';
    final invoiceRef = (seed.referenceNo ?? '').trim();
    final referenceNumber = (invoiceRef.isNotEmpty && invoiceRef != '-')
        ? invoiceRef
        : 'sb${seed.id}';
    final invoiceIds =
        selected.map((invoice) => invoice.id.toString()).toList();

    final order = <String, dynamic>{
      'kind': 'redeem',
      'currency': 'eur',
      'message': orderMessage,
      'counterpart': {
        'identifier': {
          'standard': 'iban',
          'iban': destinationIban,
        },
        'details': seed.moneriumIbanCounterpartDetails(countryCode),
      },
      'amount': amount.toStringAsFixed(2),
      'memo': '[sb:${seed.id}]',
      'referenceNumber': referenceNumber.length > 35
          ? referenceNumber.substring(0, 35)
          : referenceNumber,
    };

    var paymentInitiatedToastShown = false;
    try {
      final response = await MoneriumService.createSendMoneyOrderWithSignature(
        userId: moneriumUserId,
        walletAddress: walletAddress,
        order: order,
        invoiceId: seed.id.toString(),
        invoiceIds: invoiceIds,
      );

      final orderId = MoneriumService.extractOrderId(response);
      final initiatedTxHash = MoneriumService.extractOrderTxHash(response);

      var anyStillOpen = false;
      for (final invoice in selected) {
        if (orderId != null && orderId.isNotEmpty) {
          await MoneriumService.savePendingOrderForInvoice(
            invoiceId: invoice.id,
            orderId: orderId,
          );
          await invoiceController.updateMoneriumOrderIdForInvoice(
            invoice.id,
            orderId,
          );
        }

        if (initiatedTxHash != null && initiatedTxHash.isNotEmpty) {
          await invoiceController.updateTxHashForInvoice(
            invoice.id,
            initiatedTxHash,
          );
        }

        final latestAfterPay =
            await invoiceController.getInvoiceById(invoice.id, silent: true);
        final latestStatus =
            (latestAfterPay?.status ?? '').trim().toUpperCase();
        if (latestStatus != 'PAID') {
          anyStillOpen = true;
          await receivedInvoicesClass.updateInvoiceStatus(
            invoice.id,
            'PROCESSING',
            silent: true,
          );
        }
      }

      await onAfterInitiate?.call();

      paymentInitiatedToastShown = true;
      AppAnalytics.paySucceeded();
      if (!anyStillOpen) {
        InvoiceToastCoordinator.notifyPayerPaidInApp(
          invoiceId: '${seed.id}',
        );
        return true;
      }
      unawaited(SbFeedback.medium());
      if (orderId == null || orderId.isEmpty) {
        Get.snackbar(
          'inf_PaymentInitiatedTitle'.tr,
          selected.length > 1
              ? 'inf_PaymentInitiatedBatchNoOrder'
                  .trParams({'count': '${selected.length}'})
              : 'inf_PaymentInitiatedSingleNoOrder'.tr,
          backgroundColor: Theme.of(context).colorScheme.yellow,
          colorText: Colors.black,
          duration: const Duration(seconds: 4),
        );
        return true;
      }

      Get.snackbar(
        'inf_PaymentInitiatedTitle'.tr,
        selected.length > 1
            ? 'inf_PaymentInitiatedBatchWaiting'
                .trParams({'count': '${selected.length}'})
            : 'inf_PaymentInitiatedSingleWaiting'.tr,
        backgroundColor: Theme.of(context).colorScheme.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return true;
    } catch (error) {
      if (paymentInitiatedToastShown) {
        debugPrint('Post-initiate error (toast already shown): $error');
        return true;
      }
      if (MetamaskWalletService.isCancelled(error)) {
        AppAnalytics.payFailed(reason: 'cancelled');
        return false;
      }
      unawaited(SbFeedback.error());
      Get.snackbar(
        'err_PaymentError'.tr,
        error.toString(),
        backgroundColor: Theme.of(context).colorScheme.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
      AppAnalytics.payFailed(reason: 'error');
      return false;
    }
  } finally {
    AppLockController.endExternalAuthSession();
  }
}
