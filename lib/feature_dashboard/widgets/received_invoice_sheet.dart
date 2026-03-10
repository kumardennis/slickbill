import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:slickbill/color_scheme.dart';
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

  const ReceivedInvoiceSheet(
      {super.key,
      required this.invoice,
      required this.payInvoice,
      required this.updateInvoiceStatus,
      required this.updateInvoiceObsolete,
      required this.createCoinbaseTransaction,
      required this.createCDPEmbeddedTransaction});

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
    var unpayingStarted = useState<bool>(false);

    bool dateIsPassed =
        DateTime.now().isAfter(DateTime.parse(invoice.deadline));

    print("Sender IBAN: ${invoice.toJson()}");
    print("TXHASH: ${invoice.txHash}");

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${invoice.invoiceNo}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                        DateFormat('EEE, dd MMM yyyy')
                            .format(DateTime.parse(invoice.createdAt!)),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.gray)),
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 150,
                      child: Text(
                          '${invoice.senders?.privateUsers?.firstName} ${invoice.senders?.privateUsers?.lastName ?? ''}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.displayMedium),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                            invoice.status == 'PAID'
                                ? 'lbl_Paid'.tr
                                : 'lbl_Unpaid'.tr,
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                    color: invoice.status == 'PAID'
                                        ? Theme.of(context).colorScheme.green
                                        : dateIsPassed
                                            ? Theme.of(context).colorScheme.red
                                            : Theme.of(context)
                                                .colorScheme
                                                .yellow)),
                        const SizedBox(
                          width: 10,
                        ),
                        invoice.status == 'PAID'
                            ? FaIcon(
                                FontAwesomeIcons.circleCheck,
                                size: 20,
                                color: Theme.of(context).colorScheme.green,
                              )
                            : FaIcon(
                                FontAwesomeIcons.clockRotateLeft,
                                size: 20,
                                color: dateIsPassed
                                    ? Theme.of(context).colorScheme.red
                                    : Theme.of(context).colorScheme.yellow,
                              )
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Text(formatNumber.formatMoney(invoice.amount),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width / 2,
                      child: Wrap(
                        children: [
                          Text(
                            invoice.originalInvoiceNo != null
                                ? '#${invoice.originalInvoiceNo}'
                                : '-',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Text('lbl_OriginalInvoiceNo'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.gray))
                  ],
                ),
                Text(
                    invoice.paidOnDate != null
                        ? 'lbl_PaidOn'.trParams({
                            'date':
                                '${DateFormat('EEE, dd MMM').format(DateTime.parse(invoice.paidOnDate!))}'
                          })
                        : 'lbl_Due'.trParams({
                            'date':
                                '${DateFormat('EEE, dd MMM').format(DateTime.parse(invoice.deadline!))}'
                          }),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: invoice.paidOnDate != null
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${invoice.senders?.privateUsers?.iban ?? "-"}',
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text('lbl_IBAN'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.gray))
                  ],
                ),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(
                        text: invoice.senders?.privateUsers?.iban ?? "-"));
                    Get.snackbar('inf_Copied'.tr,
                        invoice.senders?.privateUsers?.iban ?? "-");
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 150,
                      child: Text(
                          invoice.senders?.privateUsers?.bankAccountName ??
                              invoice.senderName ??
                              '-',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    Text('lbl_AccountHolder'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.gray))
                  ],
                ),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(
                        text: invoice.senders?.privateUsers?.bankAccountName ??
                            invoice.senderName ??
                            '-'));
                    Get.snackbar(
                        'inf_Copied'.tr,
                        invoice.senders?.privateUsers?.bankAccountName ??
                            invoice.senderName ??
                            '-');
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
                          await Clipboard.setData(
                              ClipboardData(text: invoice.description));
                          Get.snackbar('inf_Copied'.tr, invoice.description);
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
                    invoice.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.light,
                          height: 1.5,
                        ),
                  ),
                  // Payment Links
                  if (invoice.description.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final urls = _extractUrls(invoice.description);
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
            if (invoice.status == 'PAID' &&
                invoice.txHash != null &&
                (invoice.txHash?.isNotEmpty ?? false)) ...[
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
                            invoice.txHash!,
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
                              ClipboardData(text: invoice.txHash!),
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
                          onTap: () async => openTxInExplorer(invoice.txHash!),
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
                        final link = buildTxUrl(invoice.txHash);
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 70,
                      child: Wrap(
                        children: [
                          Text(invoice.category ?? '-',
                              style: Theme.of(context).textTheme.displayMedium),
                        ],
                      ),
                    ),
                    Text('lbl_Category'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.gray)),
                  ],
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.referenceNo ?? '-',
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text('lbl_ReferenceNumber'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.gray))
                  ],
                ),
                GestureDetector(
                  onTap: () async {
                    if (invoice.referenceNo != null) {
                      await Clipboard.setData(
                          ClipboardData(text: invoice.referenceNo ?? ''));
                      Get.snackbar('inf_Copied'.tr, invoice.referenceNo ?? '');
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
              child: invoice.status == 'UNPAID'
                  ? ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.green),
                      onPressed: () async {
                        paymentStarted.value = true;
                        await createCDPEmbeddedTransaction(invoice);
                        paymentStarted.value = false;
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
                                      color:
                                          Theme.of(context).colorScheme.light),
                            ),
                            const SizedBox(width: 10),
                            FaIcon(
                              FontAwesomeIcons.circleCheck,
                              color: Theme.of(context).colorScheme.light,
                            )
                          ],
                        ),
                      ))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.red),
                      onPressed: () async {
                        unpayingStarted.value = true;
                        await updateInvoiceStatus!(invoice, false);
                        unpayingStarted.value = false;
                        // await openInvoice(invoice);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(15.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              unpayingStarted.value
                                  ? 'inf_StatusUpdating'.tr
                                  : 'btn_Unpay'.tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.light),
                            ),
                            const SizedBox(width: 10),
                            FaIcon(
                              FontAwesomeIcons.circleCheck,
                              color: Theme.of(context).colorScheme.light,
                            )
                          ],
                        ),
                      )),
            ),
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
