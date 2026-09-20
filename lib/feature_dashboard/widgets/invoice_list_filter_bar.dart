import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_dashboard/models/invoice_list_query.dart';
import 'package:slickbill/shared_widgets/sb_surface_card.dart';
import 'package:slickbill/theme/sb_colors.dart';

class InvoiceListFilterBar extends StatefulWidget {
  final InvoiceListQuery query;
  final ValueChanged<InvoiceListQuery> onChanged;
  final VoidCallback? onExport;
  final bool exportEnabled;
  final bool showMonthHeader;
  final bool showPills;
  final bool showSearch;

  const InvoiceListFilterBar({
    super.key,
    required this.query,
    required this.onChanged,
    this.onExport,
    this.exportEnabled = true,
    this.showMonthHeader = true,
    this.showPills = true,
    this.showSearch = true,
  });

  @override
  State<InvoiceListFilterBar> createState() => _InvoiceListFilterBarState();
}

class _InvoiceListFilterBarState extends State<InvoiceListFilterBar> {
  static const _monthHistory = 36;
  static const _debounce = Duration(milliseconds: 300);

  late final TextEditingController _search;
  Timer? _searchDebounce;

  InvoiceListQuery get query => widget.query;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: query.search);
  }

  @override
  void didUpdateWidget(covariant InvoiceListFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (query.search != oldWidget.query.search &&
        query.search != _search.text) {
      _search.text = query.search;
      _search.selection = TextSelection.collapsed(offset: _search.text.length);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

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

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_debounce, () {
      if (!mounted) return;
      if (query.search == value) return;
      widget.onChanged(query.copyWith(search: value));
    });
  }

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
                          widget.onChanged(query.copyWith(allTime: true));
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
                            widget.onChanged(
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
        widget.showMonthHeader ? 0 : 8,
        0,
        4,
      ),
      child: Column(
        children: [
          if (widget.showMonthHeader)
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
                if (widget.onExport != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'btn_ExportCsv'.tr,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.exportEnabled ? widget.onExport : null,
                    icon: Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: widget.exportEnabled
                          ? SbColors.secondary
                          : SbColors.outlineVariant,
                    ),
                  ),
                ],
              ],
            ),
          if (widget.showMonthHeader) const SizedBox(height: 12),
          if (widget.showPills)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  SbFilterPill(
                    label: 'lbl_AllBills'.tr,
                    selected: query.status == InvoiceStatusFilter.all,
                    onTap: () => widget.onChanged(
                      query.copyWith(status: InvoiceStatusFilter.all),
                    ),
                  ),
                  SbFilterPill(
                    label: 'lbl_Unpaid'.tr,
                    selected: query.status == InvoiceStatusFilter.unpaid,
                    onTap: () => widget.onChanged(
                      query.copyWith(status: InvoiceStatusFilter.unpaid),
                    ),
                  ),
                  SbFilterPill(
                    label: 'lbl_Processing'.tr,
                    selected: query.status == InvoiceStatusFilter.processing,
                    onTap: () => widget.onChanged(
                      query.copyWith(status: InvoiceStatusFilter.processing),
                    ),
                  ),
                  SbFilterPill(
                    label: 'lbl_Paid'.tr,
                    selected: query.status == InvoiceStatusFilter.paid,
                    onTap: () => widget.onChanged(
                      query.copyWith(status: InvoiceStatusFilter.paid),
                    ),
                  ),
                ],
              ),
            ),
          if (widget.showSearch) ...[
            if (widget.showPills) const SizedBox(height: 10),
            TextField(
              controller: _search,
              onChanged: (value) {
                setState(() {});
                _onSearchChanged(value);
              },
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SbColors.onSurface,
                  ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'hint_SearchNameOrDescription'.tr,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'btn_Clear'.tr,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _search.clear();
                          widget.onChanged(query.copyWith(search: ''));
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                filled: true,
                fillColor: SbColors.surfaceLowest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SbRadii.md),
                  borderSide: const BorderSide(color: SbColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SbRadii.md),
                  borderSide: const BorderSide(color: SbColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SbRadii.md),
                  borderSide: const BorderSide(color: SbColors.secondary),
                ),
              ),
            ),
          ],
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
