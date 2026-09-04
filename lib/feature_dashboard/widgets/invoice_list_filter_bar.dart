import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_dashboard/models/invoice_list_query.dart';
import 'package:slickbill/shared_widgets/sb_surface_card.dart';
import 'package:slickbill/theme/sb_colors.dart';

class InvoiceListFilterBar extends StatelessWidget {
  final InvoiceListQuery query;
  final ValueChanged<InvoiceListQuery> onChanged;
  final VoidCallback? onExport;
  final bool exportEnabled;
  final bool showMonthHeader;
  final bool showPills;

  const InvoiceListFilterBar({
    super.key,
    required this.query,
    required this.onChanged,
    this.onExport,
    this.exportEnabled = true,
    this.showMonthHeader = true,
    this.showPills = true,
  });

  static const _monthHistory = 36;

  List<DateTime> _monthOptions() {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    return List.generate(
      _monthHistory,
      (i) => DateTime(current.year, current.month - i),
    );
  }

  String get _periodLabel =>
      query.ignoresMonth ? 'lbl_AllTime'.tr : query.monthLabel;

  Future<void> _openPeriodPicker(BuildContext context) async {
    final months = _monthOptions();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: SbColors.surfaceLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SbRadii.lg)),
      ),
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.55;
        return SafeArea(
          child: SizedBox(
            height: maxHeight,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'lbl_SelectPeriod'.tr,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: SbColors.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _PeriodTile(
                        label: 'lbl_AllTime'.tr,
                        selected: query.ignoresMonth,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          onChanged(query.copyWith(allTime: true));
                        },
                      ),
                      ...months.map((month) {
                        final selected = !query.ignoresMonth &&
                            query.monthStart.year == month.year &&
                            query.monthStart.month == month.month;
                        return _PeriodTile(
                          label: DateFormat.yMMMM().format(month),
                          selected: selected,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            onChanged(
                              query.copyWith(month: month, allTime: false),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        showMonthHeader ? 0 : 8,
        0,
        4,
      ),
      child: Column(
        children: [
          if (showMonthHeader)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'lbl_PaymentOverview'.tr,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: SbColors.onSurface,
                        ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openPeriodPicker(context),
                    borderRadius: BorderRadius.circular(SbRadii.full),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: SbColors.secondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _periodLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: SbColors.secondary,
                                ),
                          ),
                          const Icon(
                            Icons.expand_more_rounded,
                            size: 16,
                            color: SbColors.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (onExport != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'btn_ExportCsv'.tr,
                    visualDensity: VisualDensity.compact,
                    onPressed: exportEnabled ? onExport : null,
                    icon: Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: exportEnabled
                          ? SbColors.secondary
                          : SbColors.outlineVariant,
                    ),
                  ),
                ],
              ],
            ),
          if (showMonthHeader) const SizedBox(height: 12),
          if (showPills)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  SbFilterPill(
                    label: 'lbl_AllBills'.tr,
                    selected: query.status == InvoiceStatusFilter.all,
                    onTap: () => onChanged(
                      query.copyWith(status: InvoiceStatusFilter.all),
                    ),
                  ),
                  SbFilterPill(
                    label: 'lbl_Unpaid'.tr,
                    selected: query.status == InvoiceStatusFilter.unpaid,
                    onTap: () => onChanged(
                      query.copyWith(status: InvoiceStatusFilter.unpaid),
                    ),
                  ),
                  SbFilterPill(
                    label: 'lbl_Processing'.tr,
                    selected: query.status == InvoiceStatusFilter.processing,
                    onTap: () => onChanged(
                      query.copyWith(status: InvoiceStatusFilter.processing),
                    ),
                  ),
                  SbFilterPill(
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
}

class _PeriodTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: SbColors.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: SbColors.secondary)
          : null,
    );
  }
}
