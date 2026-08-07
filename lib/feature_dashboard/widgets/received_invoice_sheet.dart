import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';
import 'package:slickbill/feature_auth/services/monerium_transfer_listener_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../feature_auth/utils/money_formatter.dart';
import '../models/invoice_model.dart';

class ReceivedInvoiceSheet extends HookWidget {
  final InvoiceModel invoice;
  final Function payInvoice;
  final Function updateInvoiceStatus;
  final Function updateInvoiceObsolete;
  final Function createCoinbaseTransaction;
  final Function createCDPEmbeddedTransaction;
  final Function createMoneriumTransaction;
  final String moneriumUserId;
  final String moneriumWalletAddress;
  final Future<bool> Function(InvoiceModel invoice, {bool silent})
      manualRecheckMoneriumStatus;
  final Future<InvoiceModel?> Function(int invoiceId)? refreshInvoice;

  const ReceivedInvoiceSheet(
      {super.key,
      required this.invoice,
      required this.payInvoice,
      required this.updateInvoiceStatus,
      required this.updateInvoiceObsolete,
      required this.createCoinbaseTransaction,
      required this.createCDPEmbeddedTransaction,
      required this.createMoneriumTransaction,
      required this.moneriumUserId,
      required this.moneriumWalletAddress,
      required this.manualRecheckMoneriumStatus,
      this.refreshInvoice});

  List<String> _extractUrls(String text) {
    final urlPattern = RegExp(
      r'(https?:\/\/[^\s]+)|(www\.[^\s]+)|([a-zA-Z0-9-]+\.(com|net|org|io|me|app|co)[^\s]*)',
      caseSensitive: false,
    );
    final matches = urlPattern.allMatches(text);
    return matches.map((match) => match.group(0)!).toList();
  }

  String? buildTxUrl(String? txHash) {
    if (txHash == null) return null;
    final trimmed = txHash.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.startsWith('0x')) return null;
    return 'https://basescan.org/tx/$trimmed';
  }

  Future<void> openTxInExplorer(String txHash) async {
    final url = buildTxUrl(txHash);
    if (url == null) {
      Get.snackbar('Error', 'Invalid transaction hash');
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Get.snackbar('Error', 'Could not open explorer link');
    }
  }

  @override
  Widget build(BuildContext context) {
    FormatNumber formatNumber = FormatNumber();

    var paymentStarted = useState<bool>(false);
    var recheckStarted = useState<bool>(false);
    var currentInvoice = useState<InvoiceModel>(invoice);
    var initialStatusChecked = useState<bool>(false);
    var hasMoneriumSession = useState<bool>(false);
    var initialStatusCheckInProgress = useState<bool>(false);
    final isMounted = useIsMounted();

    useEffect(() {
      if (initialStatusChecked.value) {
        return null;
      }

      final walletAddress = moneriumWalletAddress.trim();
      final status = currentInvoice.value.status.trim().toUpperCase();
      final shouldRecheck =
          status == 'PROCESSING' || status == 'UNPAID' || status == 'PENDING';

      // Already paid: nothing to heal upward; never demote on open.
      if (walletAddress.isEmpty || !shouldRecheck) {
        initialStatusChecked.value = true;
        hasMoneriumSession.value = false;
        return null;
      }

      Future<void> checkBackendStatusOnce() async {
        if (isMounted()) {
          initialStatusCheckInProgress.value = true;
        }
        try {
          final session = await MoneriumService.getStoredSession(
            userId: moneriumUserId,
          );
          final hasSession = session != null &&
              (session['accessToken']?.toString().trim() ?? '').isNotEmpty;

          if (!hasSession) {
            hasMoneriumSession.value = false;
            return;
          }

          hasMoneriumSession.value = true;
          await manualRecheckMoneriumStatus(
            currentInvoice.value,
            silent: true,
          );
          if (!isMounted()) {
            return;
          }

          if (refreshInvoice != null) {
            final refreshed = await refreshInvoice!(currentInvoice.value.id);
            if (!isMounted()) {
              return;
            }
            if (refreshed != null) {
              currentInvoice.value = refreshed;
            }
          }
        } finally {
          if (isMounted()) {
            initialStatusCheckInProgress.value = false;
            initialStatusChecked.value = true;
          }
        }
      }

      checkBackendStatusOnce();
      return null;
    }, [
      currentInvoice.value.id,
      currentInvoice.value.status,
      moneriumWalletAddress,
      moneriumUserId,
      initialStatusChecked.value
    ]);

    useEffect(() {
      final walletAddress = moneriumWalletAddress.trim();
      final status = currentInvoice.value.status.trim().toUpperCase();

      if (!initialStatusChecked.value ||
          !hasMoneriumSession.value ||
          walletAddress.isEmpty ||
          status != 'PROCESSING') {
        return null;
      }

      Future<void> startListener() async {
        final started =
            await MoneriumTransferListenerService.startWatchingInvoiceTransfer(
          invoiceId: currentInvoice.value.id,
          payerWalletAddress: walletAddress,
          onRelevantTransfer: () async {
            final didCheck = await manualRecheckMoneriumStatus(
              currentInvoice.value,
              silent: true,
            );

            if (!didCheck || !isMounted()) {
              return;
            }

            if (refreshInvoice != null) {
              final refreshed = await refreshInvoice!(currentInvoice.value.id);
              if (!isMounted()) {
                return;
              }
              if (refreshed != null) {
                currentInvoice.value = refreshed;
              }
            }
          },
        );

        if (!started) {
          debugPrint(
            '[ReceivedInvoiceSheet] transfer listener not started for invoice=${currentInvoice.value.id}',
          );
        }
      }

      startListener();

      return () {
        MoneriumTransferListenerService.stopWatchingInvoice(
          currentInvoice.value.id,
        );
      };
    }, [
      currentInvoice.value.id,
      currentInvoice.value.status,
      moneriumWalletAddress,
      initialStatusChecked.value,
      hasMoneriumSession.value
    ]);

    final displayedInvoice = currentInvoice.value;
    final normalizedStatus = displayedInvoice.status.trim().toUpperCase();
    final shouldShowRecheck = normalizedStatus != 'PAID';
    final sender = displayedInvoice.senders;
    final senderPrivateUsers = sender?.privateUsers;
    final senderFirstName = senderPrivateUsers?.firstName ?? '';
    final senderLastName = senderPrivateUsers?.lastName ?? '';
    final senderIban = senderPrivateUsers?.iban ?? '-';
    final senderAccountHolder =
        senderPrivateUsers?.bankAccountName.isNotEmpty == true
            ? senderPrivateUsers!.bankAccountName
            : displayedInvoice.senderName;

    bool dateIsPassed =
        DateTime.now().isAfter(DateTime.parse(displayedInvoice.deadline));

    print("Sender IBAN: ${displayedInvoice.toJson()}");
    print("TXHASH: ${displayedInvoice.txHash}");

    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [
            Theme.of(context).colorScheme.darkerBlue,
            Theme.of(context).colorScheme.blue,
            Theme.of(context).colorScheme.turqouise,
            Theme.of(context).colorScheme.darkerBlue,
          ],
              stops: const [
            0.0,
            0.2,
            0.7,
            0.85
          ],
              transform: GradientRotation(3.14 / 4),
              tileMode: TileMode.clamp,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight)),
      height: MediaQuery.of(context).size.height,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${displayedInvoice.invoiceNo}',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                          DateFormat('EEE, dd MMM yyyy').format(
                              DateTime.parse(displayedInvoice.createdAt)),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.gray)),
                      Text('$senderFirstName $senderLastName',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.displayMedium),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                            normalizedStatus == 'PAID'
                                ? 'lbl_Paid'.tr
                                : normalizedStatus == 'PROCESSING'
                                    ? 'Waiting'
                                    : 'lbl_Unpaid'.tr,
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                    color: normalizedStatus == 'PAID'
                                        ? Theme.of(context).colorScheme.green
                                        : normalizedStatus == 'PROCESSING'
                                            ? Theme.of(context)
                                                .colorScheme
                                                .yellow
                                            : dateIsPassed
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .red
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .yellow)),
                        const SizedBox(
                          width: 10,
                        ),
                        normalizedStatus == 'PAID'
                            ? FaIcon(
                                FontAwesomeIcons.circleCheck,
                                size: 20,
                                color: Theme.of(context).colorScheme.green,
                              )
                            : FaIcon(
                                FontAwesomeIcons.clockRotateLeft,
                                size: 20,
                                color: normalizedStatus == 'PROCESSING'
                                    ? Theme.of(context).colorScheme.yellow
                                    : dateIsPassed
                                        ? Theme.of(context).colorScheme.red
                                        : Theme.of(context).colorScheme.yellow,
                              )
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(formatNumber.formatMoney(displayedInvoice.amount),
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.light))
                  ],
                )
              ],
            ),
            if (normalizedStatus == 'PAID') ...[
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 900),
                curve: Curves.fastOutSlowIn,
                tween: Tween(begin: 0.7, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          Theme.of(context).colorScheme.green.withOpacity(0.7),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .green
                            .withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.green,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Payment successful',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.green,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (initialStatusCheckInProgress.value) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.blue.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.light.withOpacity(0.5),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Checking latest payment status...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.light,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Divider(
                color: Theme.of(context).colorScheme.gray,
                thickness: 3,
                height: 20,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayedInvoice.originalInvoiceNo != null
                            ? '#${displayedInvoice.originalInvoiceNo}'
                            : '-',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text('lbl_OriginalInvoiceNo'.tr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.gray))
                    ],
                  ),
                ),
                Text(
                    displayedInvoice.paidOnDate != null
                        ? 'lbl_PaidOn'.trParams({
                            'date':
                                '${DateFormat('EEE, dd MMM').format(DateTime.parse(displayedInvoice.paidOnDate!))}'
                          })
                        : 'lbl_Due'.trParams({
                            'date':
                                '${DateFormat('EEE, dd MMM').format(DateTime.parse(displayedInvoice.deadline))}'
                          }),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: displayedInvoice.paidOnDate != null
                            ? Theme.of(context).colorScheme.green
                            : dateIsPassed
                                ? Theme.of(context).colorScheme.red
                                : Theme.of(context).colorScheme.yellow))
              ],
            ),
            const SizedBox(
              height: 50,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderIban,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text('lbl_IBAN'.tr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.gray))
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: senderIban));
                    Get.snackbar('inf_Copied'.tr, senderIban);
                  },
                  child: FaIcon(
                    FontAwesomeIcons.copy,
                    color: Theme.of(context).colorScheme.gray,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 30,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(senderAccountHolder,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text('lbl_AccountHolder'.tr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.gray))
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: senderAccountHolder));
                    Get.snackbar('inf_Copied'.tr, senderAccountHolder);
                  },
                  child: FaIcon(
                    FontAwesomeIcons.copy,
                    color: Theme.of(context).colorScheme.gray,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 30,
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.light.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'lbl_Description'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.gray,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await Clipboard.setData(ClipboardData(
                              text: displayedInvoice.description));
                          Get.snackbar(
                              'inf_Copied'.tr, displayedInvoice.description);
                        },
                        child: FaIcon(
                          FontAwesomeIcons.copy,
                          color: Theme.of(context).colorScheme.light,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayedInvoice.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.light,
                          height: 1.5,
                        ),
                  ),
                  // Payment Links
                  if (displayedInvoice.description.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final urls = _extractUrls(displayedInvoice.description);
                        if (urls.isEmpty) return SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Divider(
                              color: Theme.of(context)
                                  .colorScheme
                                  .light
                                  .withOpacity(0.3),
                              height: 1,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Payment Links',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.light,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ...urls.map((url) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () async {
                                          String urlToOpen = url;
                                          if (!url.startsWith('http://') &&
                                              !url.startsWith('https://')) {
                                            urlToOpen = 'https://$url';
                                          }

                                          final uri = Uri.parse(urlToOpen);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri,
                                                mode: LaunchMode
                                                    .externalApplication);
                                          } else {
                                            Get.snackbar(
                                                'Error', 'Could not open link');
                                          }
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .light
                                                  .withOpacity(0.5),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.link,
                                                size: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .light,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  url,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .light,
                                                        decoration:
                                                            TextDecoration
                                                                .underline,
                                                        decorationColor:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .light,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () async {
                                        await Clipboard.setData(
                                            ClipboardData(text: url));
                                        Get.snackbar(
                                          'Copied',
                                          'Link copied to clipboard',
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .green
                                              .withOpacity(0.2),
                                          colorText: Theme.of(context)
                                              .colorScheme
                                              .light,
                                          duration: Duration(seconds: 1),
                                        );
                                      },
                                      child: Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .light
                                                .withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.copy,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .light,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            if (displayedInvoice.txHash != null &&
                (displayedInvoice.txHash?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.light.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.gray,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayedInvoice.txHash!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.light,
                                  decoration: TextDecoration.underline,
                                  decorationColor:
                                      Theme.of(context).colorScheme.light,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: displayedInvoice.txHash!),
                            );
                            Get.snackbar(
                              'Copied',
                              'Transaction hash copied',
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .green
                                  .withOpacity(0.2),
                              colorText: Theme.of(context).colorScheme.light,
                              duration: const Duration(seconds: 1),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .light
                                    .withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.copy,
                              size: 16,
                              color: Theme.of(context).colorScheme.light,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async =>
                              openTxInExplorer(displayedInvoice.txHash!),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .light
                                    .withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Theme.of(context).colorScheme.light,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (_) {
                        final link = buildTxUrl(displayedInvoice.txHash);
                        if (link == null) return const SizedBox.shrink();
                        return Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.gray,
                                  ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(
              height: 30,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayedInvoice.category ?? '-',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.displayMedium),
                      Text('lbl_Category'.tr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.gray)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 30,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayedInvoice.referenceNo ?? '-',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text('lbl_ReferenceNumber'.tr,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.gray))
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    if (displayedInvoice.referenceNo != null) {
                      await Clipboard.setData(ClipboardData(
                          text: displayedInvoice.referenceNo ?? ''));
                      Get.snackbar(
                          'inf_Copied'.tr, displayedInvoice.referenceNo ?? '');
                    }
                  },
                  child: FaIcon(
                    FontAwesomeIcons.copy,
                    color: Theme.of(context).colorScheme.gray,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 30,
            ),
            Center(
              child: normalizedStatus == 'UNPAID'
                  ? Column(
                      children: [
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.green),
                            onPressed: () async {
                              if (!isMounted()) return;

                              paymentStarted.value = true;
                              try {
                                await createMoneriumTransaction(
                                    displayedInvoice);
                                if (!isMounted()) return;

                                if (refreshInvoice != null) {
                                  final refreshed = await refreshInvoice!(
                                      displayedInvoice.id);
                                  if (!isMounted()) return;

                                  if (refreshed != null) {
                                    currentInvoice.value = refreshed;
                                  }
                                }
                              } finally {
                                if (isMounted()) {
                                  paymentStarted.value = false;
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(15.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    paymentStarted.value
                                        ? 'inf_StatusUpdating'.tr
                                        : 'btn_Pay'.tr,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .light),
                                  ),
                                  const SizedBox(width: 10),
                                  FaIcon(
                                    FontAwesomeIcons.circleCheck,
                                    color: Theme.of(context).colorScheme.light,
                                  )
                                ],
                              ),
                            )),
                      ],
                    )
                  : normalizedStatus != 'PAID'
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .blue
                                .withOpacity(0.25),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .blue
                                  .withOpacity(0.8),
                              width: 0.6,
                            ),
                          ),
                          onPressed: null,
                          child: const Padding(
                            padding: EdgeInsets.all(15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Processing payment...'),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
            ),
            if (shouldShowRecheck) ...[
              const SizedBox(
                height: 10,
              ),
              Center(
                child: OutlinedButton(
                  onPressed: () async {
                    if (!isMounted()) return;

                    recheckStarted.value = true;
                    try {
                      final didCheck =
                          await manualRecheckMoneriumStatus(displayedInvoice);
                      if (!isMounted()) return;

                      if (didCheck && refreshInvoice != null) {
                        final refreshed =
                            await refreshInvoice!(displayedInvoice.id);
                        if (!isMounted()) return;

                        if (refreshed != null) {
                          currentInvoice.value = refreshed;
                        }
                      }
                    } finally {
                      if (isMounted()) {
                        recheckStarted.value = false;
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.light,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    recheckStarted.value
                        ? 'Checking...'
                        : 'Re-check payment status',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.light,
                        ),
                  ),
                ),
              ),
            ],
            const SizedBox(
              height: 30,
            ),
            Center(
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.red),
                  onPressed: () async {
                    await updateInvoiceObsolete(invoice, true);
                    // await openInvoice(invoice);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'btn_MarkObsolete'.tr,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                  color: Theme.of(context).colorScheme.light),
                        ),
                        const SizedBox(width: 10),
                        FaIcon(
                          FontAwesomeIcons.trash,
                          color: Theme.of(context).colorScheme.light,
                        )
                      ],
                    ),
                  )),
            )
          ]),
        ),
      ),
    );
  }
}
