import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';

class InvoiceCard extends HookWidget {
  final String invoiceNo;
  final String date;
  final String dueDate;
  final String? paidOnDate;
  final String description;
  final String senderOrReeceiverName;
  final String status;
  final bool isSeen;
  final double amount;

  const InvoiceCard(
      {super.key,
      required this.invoiceNo,
      required this.date,
      required this.dueDate,
      required this.paidOnDate,
      required this.description,
      required this.senderOrReeceiverName,
      required this.status,
      required this.isSeen,
      required this.amount});

  @override
  Widget build(BuildContext context) {
    FormatNumber formatNumber = FormatNumber();

    bool dateIsPassed = DateTime.now().isAfter(DateTime.parse(dueDate));

    return (Container(
      height: 180,
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.darkGray.withOpacity(0.1),
                Theme.of(context).colorScheme.darkGray,
              ],
              stops: const [
                0.1,
                0.4,
              ],
              transform: GradientRotation(3.14 / 4),
              tileMode: TileMode.clamp,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          color: Theme.of(context).colorScheme.darkGray,
          borderRadius: BorderRadius.all(Radius.circular(10))),
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(15.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#$invoiceNo',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                      DateFormat('EEE, dd MMM yyyy')
                          .format(DateTime.parse(date!)),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.gray))
                ],
              ),
              Row(
                children: [
                  Text(status == 'PAID' ? 'lbl_Paid'.tr : 'lbl_Unpaid'.tr,
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                              color: status == 'PAID'
                                  ? Theme.of(context).colorScheme.green
                                  : dateIsPassed
                                      ? Theme.of(context).colorScheme.red
                                      : Theme.of(context).colorScheme.yellow)),
                  const SizedBox(
                    width: 10,
                  ),
                  status == 'PAID'
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
              )
            ],
          ),
          Wrap(
            children: [
              Text(description, style: Theme.of(context).textTheme.bodyMedium)
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                  paidOnDate != null
                      ? 'lbl_PaidOn'.trParams({
                          'date':
                              '${DateFormat('EEE, dd MMM, yyyy').format(DateTime.parse(paidOnDate!))}'
                        })
                      : 'lbl_Due'.trParams({
                          'date':
                              '${DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(dueDate!))}'
                        }),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: paidOnDate != null
                          ? Theme.of(context).colorScheme.green
                          : dateIsPassed
                              ? Theme.of(context).colorScheme.red
                              : Theme.of(context).colorScheme.yellow)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(formatNumber.formatMoney(amount),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: paidOnDate != null
                              ? Theme.of(context).colorScheme.green
                              : Theme.of(context).colorScheme.yellow)),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(senderOrReeceiverName,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.displaySmall),
                    ),
                  )
                ],
              )
            ],
          )
        ],
      ),
    ));
  }
}
