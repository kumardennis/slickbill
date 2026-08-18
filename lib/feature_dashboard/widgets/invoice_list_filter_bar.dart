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
    final blue = Theme.of(context).colorScheme.blue;
    final gray = Theme.of(context).colorScheme.gray;
    final next = query.nextMonth;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => onChanged(query.previousMonth),
                icon: Icon(Icons.chevron_left, color: blue),
              ),
              Expanded(
                child: Text(
                  query.monthLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.dark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: next == null ? null : () => onChanged(next),
                icon: Icon(
                  Icons.chevron_right,
                  color: next == null ? gray : blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip(
                        context,
                        label: 'lbl_All'.tr,
                        selected: query.status == InvoiceStatusFilter.all,
                        onTap: () => onChanged(
                          query.copyWith(status: InvoiceStatusFilter.all),
                        ),
                      ),
                      _chip(
                        context,
                        label: 'lbl_Unpaid'.tr,
                        selected: query.status == InvoiceStatusFilter.unpaid,
                        onTap: () => onChanged(
                          query.copyWith(status: InvoiceStatusFilter.unpaid),
                        ),
                      ),
                      _chip(
                        context,
                        label: 'lbl_Processing'.tr,
                        selected: query.status == InvoiceStatusFilter.processing,
                        onTap: () => onChanged(
                          query.copyWith(
                              status: InvoiceStatusFilter.processing),
                        ),
                      ),
                      _chip(
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
              ),
              if (onExport != null)
                IconButton(
                  tooltip: 'btn_ExportCsv'.tr,
                  onPressed: exportEnabled ? onExport : null,
                  icon: Icon(
                    Icons.download,
                    color: exportEnabled ? blue : gray,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final blue = Theme.of(context).colorScheme.blue;
    final gray = Theme.of(context).colorScheme.gray;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: blue.withOpacity(0.15),
        backgroundColor: Theme.of(context).colorScheme.light,
        side: BorderSide(color: selected ? blue : gray.withOpacity(0.4)),
        labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? blue : gray,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
