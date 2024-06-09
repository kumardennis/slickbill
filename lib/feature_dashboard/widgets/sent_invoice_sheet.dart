import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';

import '../../feature_auth/utils/money_formatter.dart';
import '../models/invoice_model.dart';

class SentInvoiceSheet extends HookWidget {
  final InvoiceModel invoice;
  final Function updateInvoiceObsolete;
  const SentInvoiceSheet(
      {super.key, required this.invoice, required this.updateInvoiceObsolete});

  @override
  Widget build(BuildContext context) {
    FormatNumber formatNumber = FormatNumber();

    bool dateIsPassed =
        DateTime.now().isAfter(DateTime.parse(invoice.deadline));

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
                    Text(
                        '${invoice.receivers.privateUsers!.firstName} ${invoice.receivers.privateUsers!.lastName}',
                        style: Theme.of(context).textTheme.displayMedium),
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
                                '${DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(invoice.paidOnDate!))}'
                          })
                        : 'lbl_Due'.trParams({
                            'date':
                                '${DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(invoice.deadline!))}'
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
                      '${invoice.senderIban ?? invoice.senders?.privateUsers?.iban}',
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
                        text: invoice.senderIban ??
                            invoice.senders?.privateUsers?.iban ??
                            ''));
                    Get.snackbar(
                        'inf_Copied'.tr,
                        invoice.senderIban ??
                            invoice.senders?.privateUsers?.iban ??
                            '');
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
                      child: Text(invoice.senderName,
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
                    await Clipboard.setData(
                        ClipboardData(text: invoice.senderName));
                    Get.snackbar('inf_Copied'.tr, invoice.senderName);
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 70,
                      child: Wrap(
                        children: [
                          Text(invoice.description,
                              style: Theme.of(context).textTheme.displayMedium),
                        ],
                      ),
                    ),
                    Text('lbl_Description'.tr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.gray))
                  ],
                ),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(
                        ClipboardData(text: invoice.description));
                    Get.snackbar('inf_Copied'.tr, invoice.description);
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
