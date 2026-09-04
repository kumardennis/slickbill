import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/widgets/from_business_badge.dart';
import 'package:slickbill/feature_dashboard/widgets/invoice_card.dart';
import 'package:slickbill/shared_widgets/sb_surface_card.dart';
import 'package:slickbill/theme/sb_colors.dart';

class GroupedInvoiceCard extends StatelessWidget {
  final List<InvoiceModel> invoices;
  final Future<void> Function(InvoiceModel invoice) onTapInvoice;

  const GroupedInvoiceCard({
    super.key,
    required this.invoices,
    required this.onTapInvoice,
  });

  @override
  Widget build(BuildContext context) {
    if (invoices.isEmpty) return const SizedBox.shrink();

    if (invoices.length == 1) {
      final i = invoices.first;
      return GestureDetector(
        onTap: () => onTapInvoice(i),
        child: InvoiceCard(
          amount: i.amount,
          invoiceNo: i.invoiceNo,
          date: i.createdAt,
          dueDate: i.deadline,
          paidOnDate: i.paidOnDate,
          description: i.description,
          senderOrReeceiverName: i.displayReceiverName,
          status: i.status,
          isSeen: i.isSeen,
          isFromBusiness: i.isFromBusiness,
          businessBadgePerspective: BusinessBadgePerspective.sentAsBusiness,
          role: InvoiceCardRole.sent,
          onFooterAction: () => onTapInvoice(i),
        ),
      );
    }

    final first = invoices.first;
    final totalAmount = invoices.fold<double>(0.0, (sum, e) => sum + e.amount);
    final paidAmount = invoices
        .where((e) => e.status.toUpperCase() == 'PAID')
        .fold<double>(0.0, (sum, e) => sum + e.amount);

    String createdLabel = first.createdAt;
    try {
      createdLabel = DateFormat('EEE, dd MMM yyyy')
          .format(DateTime.parse(first.createdAt));
    } catch (_) {}

    final hasProcessing =
        invoices.any((e) => e.status.toUpperCase() == 'PROCESSING');
    final allPaid = invoices.every((e) => e.status.toUpperCase() == 'PAID');
    final hasOverdue = invoices.any((e) {
      final status = e.status.trim().toUpperCase();
      if (status == 'PAID' ||
          status == 'PROCESSING' ||
          status == 'PENDING') {
        return false;
      }
      final due = DateTime.tryParse(e.deadline);
      return due != null && DateTime.now().isAfter(due);
    });
    final groupStatus = allPaid
        ? 'lbl_Paid'.tr
        : hasProcessing
            ? 'lbl_Processing'.tr
            : hasOverdue
                ? 'lbl_Overdue'.tr
                : 'lbl_Pending'.tr;
    final statusColor = allPaid
        ? SbColors.successGreen
        : hasProcessing
            ? SbColors.electricCyan
            : hasOverdue
                ? SbColors.error
                : SbColors.warningAmber;

    return Container(
      decoration: BoxDecoration(
        color: SbColors.surfaceLowest,
        borderRadius: BorderRadius.circular(SbRadii.md),
        boxShadow: SbShadows.cardSoft,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          controlAffinity: ListTileControlAffinity.leading,
          collapsedIconColor: SbColors.onSurfaceVariant,
          iconColor: SbColors.deepNavy,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: SbColors.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$createdLabel • ${invoices.length} invoices',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SbColors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SbStatusPill(label: groupStatus, color: statusColor),
                  const SizedBox(height: 8),
                  Text(
                    '€${totalAmount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: SbColors.onSurface,
                        ),
                  ),
                  Text(
                    '€${paidAmount.toStringAsFixed(2)} received',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SbColors.successGreen,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: invoices
              .map(
                (i) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () => onTapInvoice(i),
                    child: InvoiceCard(
                      amount: i.amount,
                      invoiceNo: i.invoiceNo,
                      date: i.createdAt,
                      dueDate: i.deadline,
                      paidOnDate: i.paidOnDate,
                      description: i.description,
                      senderOrReeceiverName: i.displayReceiverName,
                      status: i.status,
                      isSeen: i.isSeen,
                      isFromBusiness: i.isFromBusiness,
                      businessBadgePerspective:
                          BusinessBadgePerspective.sentAsBusiness,
                      role: InvoiceCardRole.sent,
                      onFooterAction: () => onTapInvoice(i),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
