import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/feature_dashboard/widgets/from_business_badge.dart';
import 'package:slickbill/shared_widgets/sb_surface_card.dart';
import 'package:slickbill/theme/sb_colors.dart';

enum InvoiceCardRole { received, sent }

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
    final normalizedStatus = status.trim().toUpperCase();
    final isPaid = normalizedStatus == 'PAID';
    final isProcessing =
        normalizedStatus == 'PROCESSING' || normalizedStatus == 'PENDING';

    DateTime? parsedDate = DateTime.tryParse(date);
    DateTime? parsedPaid = paidOnDate != null && paidOnDate!.isNotEmpty
        ? DateTime.tryParse(paidOnDate!)
        : null;
    final parsedDue = DateTime.tryParse(dueDate);
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

    final IconData icon = isPaid
        ? Icons.done_all_rounded
        : isProcessing
            ? Icons.storefront_rounded
            : isOverdue
                ? Icons.warning_amber_rounded
                : Icons.receipt_long_rounded;

    final String statusLabel = isPaid
        ? 'lbl_Paid'.tr
        : isProcessing
            ? 'lbl_Processing'.tr
            : isOverdue
                ? 'lbl_Overdue'.tr
                : 'lbl_Pending'.tr;

    final String footerMeta;
    if (isPaid && parsedPaid != null) {
      footerMeta =
          'lbl_PaidOn'.trParams({'date': DateFormat('EEE, dd MMM').format(parsedPaid)});
    } else if (role == InvoiceCardRole.sent) {
      footerMeta = 'To: $senderOrReeceiverName';
    } else {
      footerMeta = 'From: $senderOrReeceiverName';
    }

    final String footerAction = isPaid
        ? 'lbl_CheckDetails'.tr
        : isProcessing
            ? 'lbl_TrackStatus'.tr
            : role == InvoiceCardRole.sent
                ? 'lbl_SendReminder'.tr
                : 'btn_Pay'.tr;

    final dateLabelSource =
        role == InvoiceCardRole.received ? parsedDue ?? parsedDate : parsedDate;
    final dateLabel = dateLabelSource != null
        ? DateFormat('EEE, dd MMM yyyy').format(dateLabelSource)
        : (role == InvoiceCardRole.received ? dueDate : date);

    return SbSurfaceCard(
      padding: const EdgeInsets.all(SbSpace.md),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: SbSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#$invoiceNo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: SbColors.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateLabel • $description',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SbColors.onSurfaceVariant,
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
              SbStatusPill(label: statusLabel, color: accent),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatNumber.formatMoney(amount),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: SbColors.onSurface,
                  ),
            ),
          ),
          const SizedBox(height: SbSpace.sm),
          const Divider(height: 1, color: SbColors.surfaceContainer),
          const SizedBox(height: SbSpace.xs),
          Row(
            children: [
              Icon(
                isPaid
                    ? Icons.check_rounded
                    : isProcessing
                        ? Icons.qr_code_rounded
                        : Icons.person_outline_rounded,
                size: 14,
                color: SbColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  footerMeta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SbColors.onSurfaceVariant,
                      ),
                ),
              ),
              GestureDetector(
                onTap: onFooterAction,
                child: Text(
                  footerAction,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: SbColors.secondary,
                        fontSize: 12,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
