import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_dashboard/models/invoice_list_query.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/payment_class.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/invoice_csv_exporter.dart';
import 'package:slickbill/feature_dashboard/widgets/invoice_card.dart';
import 'package:slickbill/feature_dashboard/widgets/invoice_list_filter_bar.dart';
import 'package:slickbill/feature_dashboard/widgets/received_invoice_sheet.dart';
import 'package:slickbill/feature_dashboard/widgets/statistics_card.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/payment_setup_controller.dart';
import 'package:slickbill/core/services/invoice_toast_coordinator.dart';
import 'package:slickbill/services/biometric_auth_service.dart';
import 'package:slickbill/services/coinbase/coinbase_service.dart';
import 'package:slickbill/shared_widgets/cdp_webview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';

class ReceivedBills extends HookWidget {
  const ReceivedBills({super.key});

  @override
  Widget build(BuildContext context) {
    final receivedInvoicesClass = ReceivedInvoicesClass();
    final payment = PaymentClass();
    final biometricAuth = BiometricAuthService();
    final UserController userController = Get.find();
    final DigitalInvoiceController invoiceController =
        Get.find<DigitalInvoiceController>();

    final supabase = Supabase.instance.client;

    final isLoading = useState<bool>(false);
    final hasLoaded = useState<bool>(false);
    final invoices = useState<List<InvoiceModel>?>([]);
    final pending = useState<double?>(0.0);
    final paidThisMonth = useState<double?>(0.0);
    final callInProgress = useState<bool>(false);
    final filter = useState(InvoiceListQuery(
      month: currentInvoiceMonth(),
      status: InvoiceStatusFilter.all,
    ));
    final fetchRef = useRef<Future<void> Function()>(() async {});

    Future<void> getInvoices() async {
      if (!context.mounted) return;
      isLoading.value = true;
      final current = filter.value;

      final results = await Future.wait([
        receivedInvoicesClass.getPrivateReceivedInvoices(query: current),
        receivedInvoicesClass.getOpenInvoicesSum(),
        receivedInvoicesClass.getPaidInMonth(current.monthStart),
      ]);
      if (!context.mounted) return;

      final rows = results[0] as List<InvoiceModel>?;
      if (rows != null) {
        invoices.value = rows;
      }
      pending.value = results[1] as double? ?? 0.0;
      paidThisMonth.value = results[2] as double? ?? 0.0;
      isLoading.value = false;
      hasLoaded.value = true;
    }

    fetchRef.value = getInvoices;

    Future<void> updateInvoiceStatus(
      InvoiceModel invoice,
      dynamic statusOrIsPaid, {
      bool closeSheet = true,
    }) async {
      await receivedInvoicesClass.updateInvoiceStatus(
        invoice.id,
        statusOrIsPaid,
      );
      await getInvoices();
      if (!context.mounted) return;
      callInProgress.value = false;
      if (!closeSheet) {
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    Future<void> payInvoice(InvoiceModel invoice, bool isPaid) async {
      final token = await payment.getPaymentToken("LHV");

      if (token.isEmpty) {
        return;
      }

      final paymentSuccess = await payment.createSepaTransfer(
          "LHV", token, invoice.amount.toString());

      if (!paymentSuccess) {
        return;
      }

      await updateInvoiceStatus(invoice, isPaid);
    }

    Future<void> createCoinbaseTransaction(
        InvoiceModel invoice, bool isPaid) async {
      final authenticated = await biometricAuth.authenticateWithBiometrics(
        reason:
            'Authenticate to confirm payment of €${invoice.amount.toStringAsFixed(2)}',
      );

      if (!authenticated) {
        Get.snackbar(
          'Authentication Failed',
          'Biometric authentication is required to make payments.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      print('Creating Coinbase transaction...');
      print(invoice.senders?.privateUsers?.users);
      if (invoice.senders == null ||
          invoice.senders!.privateUsers!.users == null ||
          invoice.senders!.privateUsers!.users!.username.isEmpty) {
        Get.snackbar(
          'Error',
          'Sender Coinbase account information is missing.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }
      final payment = await CoinbaseService.transferEURC(
        fromAccountName: userController.user.value.username,
        toAccountName: invoice.senders!.privateUsers!.users!.username,
        amount: invoice.amount,
      );

      if (!payment.containsKey('userOpHash')) {
        Get.snackbar(
          'Error',
          'Coinbase transaction failed.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );

        return;
      }

      await updateInvoiceStatus(invoice, isPaid);
    }

    Future<void> createCDPEmbeddedTransaction(InvoiceModel invoice) async {
      final walletAddress = userController.user.value.cdpWalletId;
      if (walletAddress == null || walletAddress.isEmpty) {
        Get.snackbar(
          'Wallet not connected',
          'Please connect your wallet before paying.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Open embedded wallet pay page; auto-close when txHash is available
      const baseUrl = 'https://slickbills-wallet-client.vercel.app';
      final result = await Get.to(() => CdpWebView(
            url:
                '$baseUrl/wallet/pay?to=${invoice.senders!.privateUsers!.users!.cdpWalletId}&amount=${invoice.amount}&description=${Uri.encodeComponent(invoice.description)}&receiver=${invoice.senders!.privateUsers!.firstName}',
            title: 'Send Payment',
            accessToken: userController.user.value.accessToken,
            autoCloseMode: CdpAutoCloseMode.pay,
          ));

      if (result == null) {
        Get.snackbar(
          'Payment Cancelled',
          'You cancelled the payment.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );

        return;
      }

      // If the WebView returns a txHash, consider it success and update invoice status
      final txHash = result['txHash'];
      if (txHash == null ||
          txHash == 'null' ||
          (txHash is String && txHash.isEmpty)) {
        Get.snackbar(
          'Error',
          'Payment was not completed.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      Get.snackbar(
        'Success',
        'Transaction: $txHash',
        backgroundColor: Theme.of(context).colorScheme.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      await invoiceController.updateTxHashForInvoice(invoice.id, txHash);

      await updateInvoiceStatus(invoice, true);
    }

    Future<void> createMoneriumTransaction(InvoiceModel invoice) async {
      final user = userController.user.value;
      final moneriumUserId = PaymentSetupController.resolveMoneriumUserId(user);
      final email = user.email.trim();

      final walletAddress = user.metamaskWalletAddress?.trim() ?? '';
      if (walletAddress.isEmpty) {
        Get.snackbar(
          'Wallet not connected',
          'Please connect your MetaMask wallet before paying.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      final destinationIban =
          invoice.senderIban?.trim() ?? invoice.senders?.privateUsers?.iban;
      if (destinationIban == null || destinationIban.trim().isEmpty) {
        Get.snackbar(
          'IBAN missing',
          'Recipient IBAN is missing for this invoice.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      if (email.isEmpty) {
        Get.snackbar(
          'Email missing',
          'Your account email is required to connect Monerium.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      try {
        await MoneriumService.ensureConnected(
          userId: moneriumUserId,
          email: email,
          onWillOpenLogin: () {
            Get.snackbar(
              'Connecting Monerium',
              'Sign in to continue the payment.',
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
          'Monerium connect failed',
          'Could not connect automatically. Try again, or finish setup in Profile.',
          backgroundColor: Theme.of(context).colorScheme.yellow,
          colorText: Colors.black,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      final recipientName =
          '${invoice.senders?.privateUsers?.firstName ?? ''} ${invoice.senders?.privateUsers?.lastName ?? ''}'
              .trim();
      final normalizedIban =
          destinationIban.replaceAll(RegExp(r'\s+'), '').toUpperCase();
      final countryCode = RegExp(r'^[A-Z]{2}').hasMatch(normalizedIban)
          ? normalizedIban.substring(0, 2)
          : 'EE';
      final nowUtc = DateTime.now().toUtc();
      final timestamp =
          '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}T${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')}Z';
      final counterpartName = recipientName.isNotEmpty
          ? recipientName
          : (invoice.senderName.trim().isNotEmpty
              ? invoice.senderName.trim()
              : 'Invoice Recipient');

      final senderFirstName = invoice.senders?.privateUsers?.firstName.trim();
      final senderLastName = invoice.senders?.privateUsers?.lastName.trim();
      final nameParts = counterpartName
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList(growable: false);

      final counterpartFirstName =
          (senderFirstName != null && senderFirstName.isNotEmpty)
              ? senderFirstName
              : (nameParts.isNotEmpty ? nameParts.first : 'Invoice');
      final counterpartLastName =
          (senderLastName != null && senderLastName.isNotEmpty)
              ? senderLastName
              : (nameParts.length > 1
                  ? nameParts.sublist(1).join(' ')
                  : 'Recipient');
      final orderMessage =
          'Send EUR ${invoice.amount.toStringAsFixed(2)} to $normalizedIban at $timestamp';
      final invoiceRef = (invoice.referenceNo ?? '').trim();
      final referenceNumber = (invoiceRef.isNotEmpty && invoiceRef != '-')
          ? invoiceRef
          : 'sb${invoice.id}';

      final order = <String, dynamic>{
        'kind': 'redeem',
        'currency': 'eur',
        'message': orderMessage,
        'counterpart': {
          'identifier': {
            'standard': 'iban',
            'iban': normalizedIban,
          },
          'details': {
            'firstName': counterpartFirstName,
            'lastName': counterpartLastName,
            'country': countryCode,
          },
        },
        'amount': invoice.amount.toStringAsFixed(2),
        'memo': '[sb:${invoice.id}]',
        'referenceNumber': referenceNumber.length > 35
            ? referenceNumber.substring(0, 35)
            : referenceNumber,
      };

      var paymentInitiatedToastShown = false;
      try {
        final response =
            await MoneriumService.createSendMoneyOrderWithSignature(
          userId: moneriumUserId,
          walletAddress: walletAddress,
          order: order,
          invoiceId: invoice.id.toString(),
        );

        final orderId = MoneriumService.extractOrderId(response);
        final initiatedTxHash = MoneriumService.extractOrderTxHash(response);

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
          await receivedInvoicesClass.updateInvoiceStatus(
            invoice.id,
            'PROCESSING',
            silent: true,
          );
        }
        await getInvoices();

        paymentInitiatedToastShown = true;
        if (latestStatus == 'PAID') {
          InvoiceToastCoordinator.notifyPayerPaidInApp(
            invoiceId: '${invoice.id}',
          );
          return;
        }
        if (orderId == null || orderId.isEmpty) {
          Get.snackbar(
            'Payment Initiated',
            'Payment was initiated and marked as waiting. Re-check status shortly.',
            backgroundColor: Theme.of(context).colorScheme.yellow,
            colorText: Colors.black,
            duration: const Duration(seconds: 4),
          );
          return;
        }

        Get.snackbar(
          'Payment Initiated',
          'Invoice marked as waiting. Use Re-check payment status to fetch latest order state.',
          backgroundColor: Theme.of(context).colorScheme.blue,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } catch (error) {
        if (paymentInitiatedToastShown) {
          debugPrint('Post-initiate error (toast already shown): $error');
          return;
        }
        Get.snackbar(
          'Payment Error',
          error.toString(),
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    }

    Future<bool> manualRecheckMoneriumStatus(
      InvoiceModel invoice, {
      bool silent = false,
    }) async {
      final userId = userController.user.value.privateUserId.toString();
      final currentStatus = invoice.status.trim().toUpperCase();
      final alreadyPaid = currentStatus == 'PAID';
      final invoiceOrderId = invoice.moneriumOrderId?.trim() ?? '';
      final savedOrderId = await MoneriumService.getPendingOrderForInvoice(
        invoiceId: invoice.id,
      );
      final orderIdForRecheck = invoiceOrderId.isNotEmpty
          ? invoiceOrderId
          : (savedOrderId?.trim() ?? '');

      Map<String, dynamic> recheck;
      if (orderIdForRecheck.isNotEmpty) {
        recheck = await MoneriumService.recheckOrderById(
          userId: userId,
          orderId: orderIdForRecheck,
        );
      } else {
        final txHash = invoice.txHash?.trim() ?? '';
        if (txHash.isEmpty) {
          if (!silent) {
            Get.snackbar(
              'Missing Tracking Info',
              'No Monerium order id or transaction hash found for this invoice yet.',
              backgroundColor: Theme.of(context).colorScheme.yellow,
              colorText: Colors.black,
              duration: const Duration(seconds: 3),
            );
          }
          return false;
        }

        recheck = await MoneriumService.recheckOrderByTxHash(
          userId: userId,
          txHash: txHash,
        );
      }

      final didCheckMonerium = true;

      final resolvedOrderId = recheck['orderId']?.toString().trim();
      if (resolvedOrderId != null && resolvedOrderId.isNotEmpty) {
        await MoneriumService.savePendingOrderForInvoice(
          invoiceId: invoice.id,
          orderId: resolvedOrderId,
        );
        await invoiceController.updateMoneriumOrderIdForInvoice(
          invoice.id,
          resolvedOrderId,
        );
      }

      final state = recheck['state']?.toString().toLowerCase();
      final resolvedTxHash = recheck['txHash']?.toString().trim();
      if (resolvedTxHash != null && resolvedTxHash.isNotEmpty) {
        await invoiceController.updateTxHashForInvoice(
          invoice.id,
          resolvedTxHash,
        );
      }

      if (state == 'processed' ||
          (resolvedTxHash != null &&
              resolvedTxHash.isNotEmpty &&
              state != 'rejected')) {
        await MoneriumService.clearPendingOrderForInvoice(
            invoiceId: invoice.id);
        // Webhook may already have set PAID + notified. Don't call
        // update-invoice-status again (that would re-notify the sender).
        final latest =
            await invoiceController.getInvoiceById(invoice.id, silent: true);
        final latestStatus =
            (latest?.status ?? invoice.status).trim().toUpperCase();
        if (latestStatus != 'PAID') {
          await updateInvoiceStatus(invoice, true, closeSheet: false);
        } else {
          await getInvoices();
        }
        if (!silent) {
          InvoiceToastCoordinator.notifyPayerPaidInApp(
            invoiceId: '${invoice.id}',
          );
        }
        return didCheckMonerium;
      }

      if (state == 'rejected') {
        await MoneriumService.clearPendingOrderForInvoice(
            invoiceId: invoice.id);
        // Never demote an already-paid invoice back to unpaid.
        if (!alreadyPaid) {
          await updateInvoiceStatus(invoice, false, closeSheet: false);
          if (!silent) {
            Get.snackbar(
              'Payment Rejected',
              'Monerium rejected this payment. Invoice was set back to unpaid.',
              backgroundColor: Theme.of(context).colorScheme.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
            );
          }
        } else if (!silent) {
          Get.snackbar(
            'Payment Rejected',
            'Monerium reports rejected, but this invoice stays paid.',
            backgroundColor: Theme.of(context).colorScheme.yellow,
            colorText: Colors.black,
            duration: const Duration(seconds: 4),
          );
        }
        return didCheckMonerium;
      }

      if (silent) {
        return didCheckMonerium;
      }

      if (recheck['found'] == true) {
        Get.snackbar(
          'Payment Pending',
          'Order is still pending. Re-check again shortly.',
          backgroundColor: Theme.of(context).colorScheme.yellow,
          colorText: Colors.black,
          duration: const Duration(seconds: 3),
        );
        return didCheckMonerium;
      }

      Get.snackbar(
        'Not Found Yet',
        'Order data not found for this transaction hash yet. Try again shortly.',
        backgroundColor: Theme.of(context).colorScheme.yellow,
        colorText: Colors.black,
        duration: const Duration(seconds: 3),
      );
      return didCheckMonerium;
    }

    Future<void> updateInvoiceObsolete(
        InvoiceModel invoice, bool isObsolete) async {
      await receivedInvoicesClass.updateInvoiceObsolete(invoice.id, isObsolete);
      await getInvoices();
      if (!context.mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    }

    // Auto re-check PROCESSING invoices once when app comes back from browser
    useEffect(() {
      final observer = _ResumeObserver(onResume: () {
        final toRecheck = (invoices.value ?? []).where((i) {
          final status = i.status.trim().toUpperCase();
          return status == 'PROCESSING' ||
              status == 'UNPAID' ||
              status == 'PENDING';
        }).toList();
        for (final inv in toRecheck) {
          manualRecheckMoneriumStatus(inv, silent: true);
        }
      });
      WidgetsBinding.instance.addObserver(observer);
      return () => WidgetsBinding.instance.removeObserver(observer);
    }, []);

    Future<void> openInvoice(InvoiceModel invoice) async {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.94,
          child: ReceivedInvoiceSheet(
            invoice: invoice,
            payInvoice: payInvoice,
            updateInvoiceStatus: updateInvoiceStatus,
            createCoinbaseTransaction: createCoinbaseTransaction,
            createCDPEmbeddedTransaction: createCDPEmbeddedTransaction,
            createMoneriumTransaction: createMoneriumTransaction,
            moneriumUserId: userController.user.value.privateUserId
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? userController.user.value.privateUserId!.toString()
                : userController.user.value.id.toString(),
            moneriumWalletAddress:
                userController.user.value.metamaskWalletAddress?.trim() ?? '',
            manualRecheckMoneriumStatus: manualRecheckMoneriumStatus,
            refreshInvoice: (int invoiceId) async {
              final rows =
                  await receivedInvoicesClass.getPrivateReceivedInvoices(
                id: invoiceId,
              );

              if (rows == null || rows.isEmpty) {
                return null;
              }

              return rows.first;
            },
            updateInvoiceObsolete: updateInvoiceObsolete,
          ),
        ),
      );
    }

    useEffect(() {
      Future.microtask(() async {
        await getInvoices();
      });
      return null;
    }, [filter.value.month.year, filter.value.month.month, filter.value.status, filter.value.allTime]);

    useEffect(() {
      final refreshWorker =
          ever<int>(invoiceController.receivedListRefreshRequest, (_) {
        fetchRef.value();
      });

      final changes = supabase
          .channel('invoice-updates-received-bills')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'digital_invoices',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiverPrivateUserId',
              value: userController.user.value.privateUserId.toString(),
            ),
            callback: (payload) => fetchRef.value(),
          )
          .subscribe();

      return () async {
        refreshWorker.dispose();
        try {
          await supabase.removeChannel(changes);
        } catch (_) {}
      };
    }, [userController.user.value.privateUserId]);

    final monthName =
        DateFormat.MMMM().format(filter.value.monthStart);
    final rows = invoices.value ?? <InvoiceModel>[];

    return Column(
      children: [
        InvoiceListFilterBar(
          query: filter.value,
          onChanged: (next) => filter.value = next,
          exportEnabled: rows.isNotEmpty,
          onExport: () {
            InvoiceCsvExporter.exportReceived(
              invoices: rows,
              query: filter.value,
            );
          },
        ),
        if (isLoading.value && hasLoaded.value)
          LinearProgressIndicator(
            minHeight: 2,
            color: Theme.of(context).colorScheme.blue,
            backgroundColor:
                Theme.of(context).colorScheme.blue.withOpacity(0.15),
          ),
        Expanded(
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.light,
            backgroundColor: Theme.of(context).colorScheme.blue,
            onRefresh: getInvoices,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0.0, 12.0, 20.0, 20.0),
                child: !hasLoaded.value && isLoading.value
                    ? const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Column(
                        children: [
                          StatisticsCard(
                            pendingAmount: pending.value,
                            paidAmount: paidThisMonth.value,
                            pendingLabel: 'lbl_PendingToPay'.tr,
                            paidLabel: 'lbl_PaidInMonth'.trParams({
                              'month': monthName,
                            }),
                          ),
                          const SizedBox(height: 12),
                          if (rows.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 24, 0, 0),
                              child: Text(
                                filter.value.emptyListNeedsMonth
                                    ? filter.value.emptyListLabelKey.trParams({
                                        'month': monthName,
                                      })
                                    : filter.value.emptyListLabelKey.tr,
                              ),
                            )
                          else
                            Column(
                              children: rows
                                  .map((invoice) => Padding(
                                        padding:
                                            const EdgeInsets.only(top: 20.0),
                                        child: GestureDetector(
                                          onTap: () async {
                                            await openInvoice(invoice);
                                          },
                                          child: InvoiceCard(
                                              amount: invoice.amount,
                                              invoiceNo: invoice.invoiceNo,
                                              date: invoice.createdAt,
                                              dueDate: invoice.deadline,
                                              paidOnDate: invoice.paidOnDate,
                                              description: invoice.description,
                                              senderOrReeceiverName:
                                                  invoice.displaySenderName,
                                              status: invoice.status,
                                              isSeen: invoice.isSeen,
                                              isFromBusiness:
                                                  invoice.isFromBusiness),
                                        ),
                                      ))
                                  .toList(),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumeObserver extends WidgetsBindingObserver {
  final VoidCallback onResume;
  _ResumeObserver({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}
