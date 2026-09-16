import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/feature_dashboard/widgets/from_business_badge.dart';
import 'package:slickbill/shared_widgets/sb_receipt_stamp.dart';
import 'package:slickbill/shared_widgets/sb_status_mark.dart';
import 'package:slickbill/shared_widgets/sb_surface_card.dart';
import 'package:slickbill/theme/sb_colors.dart';

enum InvoiceCardRole { received, sent }

class InvoiceCard extends StatelessWidget {
  final String invoiceNo;
  final String date;
  final String dueDate;
  final String? paidOnDate;
  final String description;
  final String senderOrReeceiverName;
  final String status;
  final bool isSeen;
  final double amount;
  final bool isFromBusiness;
  final BusinessBadgePerspective businessBadgePerspective;
  final InvoiceCardRole role;
  final VoidCallback? onFooterAction;

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
      required this.amount,
      this.isFromBusiness = false,
      this.businessBadgePerspective = BusinessBadgePerspective.fromBusiness,
      this.role = InvoiceCardRole.received,
      this.onFooterAction});

  @override
  Widget build(BuildContext context) {
    final formatNumber = FormatNumber();
    final money = formatNumber.formatMoney(amount);
    final normalizedStatus = status.trim().toUpperCase();
    final isPaid = normalizedStatus == 'PAID';
    final isProcessing =
        normalizedStatus == 'PROCESSING' || normalizedStatus == 'PENDING';

    final parsedDate = DateTime.tryParse(date)?.toLocal();
    final parsedPaid = paidOnDate != null && paidOnDate!.isNotEmpty
        ? DateTime.tryParse(paidOnDate!)?.toLocal()
        : null;
    final parsedDue = DateTime.tryParse(dueDate)?.toLocal();
    final isOverdue = !isPaid &&
        !isProcessing &&
        parsedDue != null &&
        DateTime.now().isAfter(parsedDue);

    final Color accent = isPaid
        ? SbColors.successGreen
        : isProcessing
            ? SbColors.electricCyan
            : isOverdue
                ? SbColors.error
                : SbColors.warningAmber;

    final mark = isPaid
        ? SbInvoiceStatusMark.paid
        : isProcessing
            ? SbInvoiceStatusMark.processing
            : isOverdue
                ? SbInvoiceStatusMark.overdue
                : SbInvoiceStatusMark.unpaid;

    final String statusLabel = isPaid
        ? 'lbl_Paid'.tr
        : isProcessing
            ? 'lbl_Processing'.tr
            : isOverdue
                ? 'lbl_Overdue'.tr
                : 'lbl_Pending'.tr;

    final counterpart = role == InvoiceCardRole.sent
        ? 'To: $senderOrReeceiverName'
        : 'From: $senderOrReeceiverName';

    final String footerAction = isPaid
        ? 'lbl_CheckDetails'.tr
        : isProcessing
            ? 'lbl_TrackStatus'.tr
            : role == InvoiceCardRole.sent
                ? 'lbl_SendReminder'.tr
                : 'btn_Pay'.tr;

    final createdLabel =
        parsedDate != null ? DateFormat('dd MMM').format(parsedDate) : date;
    final paidLabel = parsedPaid != null
        ? 'lbl_PaidOn'.trParams({
            'date': DateFormat('EEE, dd MMM').format(parsedPaid),
          })
        : null;
    final dueLabel = parsedDue != null
        ? 'lbl_Due'.trParams({'date': DateFormat('dd MMM').format(parsedDue)})
        : null;

    final itemLabel = description.trim().isEmpty ? '—' : description.trim();

    return SbViewportTicker(
      child: Container(
        decoration: BoxDecoration(
          color: SbColors.surfaceLowest,
          borderRadius: BorderRadius.circular(SbRadii.md),
          boxShadow: SbShadows.cardSoft,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(SbSpace.md),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SbStatusMark(mark: mark),
                      const SizedBox(width: SbSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#$invoiceNo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: SbColors.onSurface,
                                  ),
                            ),
                            if (isFromBusiness) ...[
                              const SizedBox(height: 6),
                              FromBusinessBadge(
                                perspective: businessBadgePerspective,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            money,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: SbColors.onSurface,
                                ),
                          ),
                          if (!isPaid && !isOverdue) ...[
                            const SizedBox(height: 4),
                            SbStatusPill(label: statusLabel, color: accent),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const SbDashedDivider(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      itemLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SbColors.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: SbColors.outline,
                              fontSize: 11,
                            ),
                        children: [
                          TextSpan(text: createdLabel),
                          if (isPaid && paidLabel != null) ...[
                            const TextSpan(text: '  ·  '),
                            TextSpan(
                              text: paidLabel,
                              style: const TextStyle(
                                  color: SbColors.successGreen),
                            ),
                          ] else if (dueLabel != null) ...[
                            const TextSpan(text: '  ·  '),
                            TextSpan(
                              text: dueLabel,
                              style: TextStyle(
                                color: isOverdue
                                    ? SbColors.error
                                    : SbColors.outline,
                                decoration: isOverdue || !isProcessing
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                                decorationColor: isOverdue
                                    ? SbColors.error.withValues(alpha: 0.7)
                                    : SbColors.warningAmber
                                        .withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SbDashedDivider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: SbColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          counterpart,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: SbColors.onSurfaceVariant,
                                  ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onFooterAction,
                        child: Text(
                          footerAction,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: SbColors.secondary,
                                fontSize: 12,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isPaid)
              Positioned(
                right: 86,
                top: 10,
                child: Opacity(
                  opacity: 0.82,
                  child: SbReceiptStamp(
                    label: 'lbl_Paid'.tr,
                    color: SbColors.successGreen,
                    animate: true,
                  ),
                ),
              )
            else if (isOverdue)
              Positioned(
                right: 72,
                top: 10,
                child: Opacity(
                  opacity: 0.78,
                  child: SbReceiptStamp(
                    label: 'lbl_Overdue'.tr,
                    color: SbColors.error,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
