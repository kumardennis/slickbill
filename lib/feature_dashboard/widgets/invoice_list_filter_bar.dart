import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/models/invoice_list_query.dart';

class InvoiceListFilterBar extends StatelessWidget {
  final InvoiceListQuery query;
  final ValueChanged<InvoiceListQuery> onChanged;
  final VoidCallback? onExport;
  final bool exportEnabled;

  const InvoiceListFilterBar({
    super.key,
    required this.query,
    required this.onChanged,
    this.onExport,
    this.exportEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final navy = Theme.of(context).colorScheme.blue;
    final accent = Theme.of(context).colorScheme.lighterBlue;
    final gray = Theme.of(context).colorScheme.gray;
    final monthActive = query.monthFilterActive;
    final next = monthActive ? query.nextMonth : null;
    final periodText =
        query.ignoresMonth ? query.periodLabelKey.tr : query.monthLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: navy.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: navy.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      _monthArrow(
                        context,
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Previous month',
                        enabled: monthActive,
                        onTap: monthActive
                            ? () => onChanged(query.previousMonth)
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          periodText,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: monthActive
                                        ? navy
                                        : navy.withOpacity(0.7),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      _monthArrow(
                        context,
                        icon: Icons.chevron_right_rounded,
                        tooltip: 'Next month',
                        enabled: next != null,
                        onTap: next == null ? null : () => onChanged(next),
                      ),
                    ],
                  ),
                ),
              ),
              if (onExport != null) ...[
                const SizedBox(width: 10),
                Tooltip(
                  message: 'btn_ExportCsv'.tr,
                  child: Material(
                    color: exportEnabled
                        ? accent
                        : gray.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: exportEnabled ? onExport : null,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 44,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.download_rounded,
                                size: 18,
                                color: exportEnabled ? Colors.white : gray,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'CSV',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: exportEnabled
                                          ? Colors.white
                                          : gray,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: monthActive ? navy : gray,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'lbl_FilterByMonth'.tr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: navy,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Switch.adaptive(
                value: monthActive,
                activeColor: navy,
                onChanged: (enabled) {
                  onChanged(query.copyWith(allTime: !enabled));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: navy.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(3),
            child: Row(
              children: [
                _segment(
                  context,
                  label: 'lbl_All'.tr,
                  selected: query.status == InvoiceStatusFilter.all,
                  onTap: () => onChanged(
                    query.copyWith(status: InvoiceStatusFilter.all),
                  ),
                ),
                _segment(
                  context,
                  label: 'lbl_Unpaid'.tr,
                  selected: query.status == InvoiceStatusFilter.unpaid,
                  onTap: () => onChanged(
                    query.copyWith(status: InvoiceStatusFilter.unpaid),
                  ),
                ),
                _segment(
                  context,
                  label: 'lbl_Processing'.tr,
                  selected: query.status == InvoiceStatusFilter.processing,
                  onTap: () => onChanged(
                    query.copyWith(status: InvoiceStatusFilter.processing),
                  ),
                ),
                _segment(
                  context,
                  label: 'lbl_Paid'.tr,
                  selected: query.status == InvoiceStatusFilter.paid,
                  onTap: () => onChanged(
                    query.copyWith(status: InvoiceStatusFilter.paid),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthArrow(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    final navy = Theme.of(context).colorScheme.blue;
    final gray = Theme.of(context).colorScheme.gray;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: enabled ? onTap : null,
      icon: Icon(
        icon,
        size: 26,
        color: enabled ? navy : gray.withOpacity(0.45),
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final navy = Theme.of(context).colorScheme.blue;
    final gray = Theme.of(context).colorScheme.gray;

    return Expanded(
      child: Material(
        color: selected ? navy : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? Colors.white : gray,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
