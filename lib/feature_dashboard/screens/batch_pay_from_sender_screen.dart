import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/app_lock_controller.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/batch_pay_from_sender.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/shared_widgets/sb_surface_card.dart';
import 'package:slickbill/theme/sb_colors.dart';

class BatchPayFromSenderScreen extends HookWidget {
  final InvoiceModel seedInvoice;
  final Future<bool> Function(
    List<InvoiceModel> invoices, {
    void Function(String phase)? onPhase,
  }) paySelected;

  const BatchPayFromSenderScreen({
    super.key,
    required this.seedInvoice,
    required this.paySelected,
  });

  @override
  Widget build(BuildContext context) {
    final formatNumber = FormatNumber();
    final isLoading = useState(true);
    final invoices = useState<List<InvoiceModel>>([seedInvoice]);
    final selectedIds = useState<Set<int>>({seedInvoice.id});
    final paymentPhase = useState<String?>(null);
    final senderName = seedInvoice.displaySenderName.trim().isEmpty
        ? 'lbl_ThisSender'.tr
        : seedInvoice.displaySenderName.trim();

    useEffect(() {
      Future<void> load() async {
        final senderId = BatchPayFromSender.senderId(seedInvoice);
        List<InvoiceModel> fetched = const [];
        if (senderId != null) {
          fetched = await ReceivedInvoicesClass().getUnpaidFromSender(
                senderPrivateUserId: senderId,
              ) ??
              const [];
        }
        if (!context.mounted) return;
        final rows = BatchPayFromSender.eligibleWithSeed(
          seed: seedInvoice,
          candidates: fetched,
        );
        invoices.value = rows;
        selectedIds.value = rows.map((invoice) => invoice.id).toSet();
        isLoading.value = false;
      }

      load();
      return null;
    }, [seedInvoice.id]);

    final selected = invoices.value
        .where((invoice) => selectedIds.value.contains(invoice.id))
        .toList();
    final total = BatchPayFromSender.sum(selected);
    final paying = paymentPhase.value != null;
    final allCount = invoices.value.length;
    final allSelected =
        allCount > 0 && selectedIds.value.length == allCount;
    final noneSelected = selectedIds.value.isEmpty;

    void setSelected(Set<int> next) {
      selectedIds.value = next;
    }

    void toggleId(int id) {
      final next = {...selectedIds.value};
      if (next.contains(id)) {
        next.remove(id);
      } else {
        next.add(id);
      }
      setSelected(next);
    }

    void toggleSelectAll() {
      if (allSelected) {
        setSelected({});
      } else {
        setSelected(invoices.value.map((invoice) => invoice.id).toSet());
      }
    }

    return Scaffold(
      backgroundColor: SbColors.surface,
      appBar: AppBar(
        title: Text('hd_PayFromSender'.trParams({'name': senderName})),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'inf_PayFromSenderHint'.trParams({'name': senderName}),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SbColors.onSurfaceVariant,
                  ),
            ),
          ),
          if (!isLoading.value && invoices.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 4),
              child: Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: noneSelected ? false : (allSelected ? true : null),
                    onChanged: paying ? null : (_) => toggleSelectAll(),
                  ),
                  GestureDetector(
                    onTap: paying ? null : toggleSelectAll,
                    child: Text(
                      'lbl_SelectAll'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : invoices.value.isEmpty
                    ? Center(child: Text('lbl_NoUnpaidInvoices'.tr))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: invoices.value.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final invoice = invoices.value[index];
                          final checked = selectedIds.value.contains(invoice.id);
                          final created = DateTime.tryParse(invoice.createdAt)
                              ?.toLocal();
                          final dateLabel = created != null
                              ? DateFormat('dd MMM yyyy').format(created)
                              : invoice.createdAt;
                          final description = invoice.description.trim().isEmpty
                              ? '#${invoice.invoiceNo}'
                              : invoice.description.trim();

                          return SbSurfaceCard(
                            onTap: paying ? null : () => toggleId(invoice.id),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: checked,
                                  onChanged: paying
                                      ? null
                                      : (_) => toggleId(invoice.id),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: SbColors.outline,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  formatNumber.formatMoney(invoice.amount),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.green,
                    disabledBackgroundColor:
                        Theme.of(context).colorScheme.green.withValues(alpha: 0.5),
                  ),
                  onPressed: paying || selected.isEmpty
                      ? null
                      : () async {
                          final confirmed =
                              await AppLockController.confirmSensitiveAction(
                            reason: 'lbl_ConfirmPayment'.trParams({
                              'amount': formatNumber.formatMoney(total),
                            }),
                          );
                          if (!confirmed || !context.mounted) return;

                          paymentPhase.value = 'checkingBalance';
                          final ok = await paySelected(
                            selected,
                            onPhase: (phase) {
                              if (context.mounted) {
                                paymentPhase.value = phase;
                              }
                            },
                          );
                          if (!context.mounted) return;
                          paymentPhase.value = null;
                          if (ok) {
                            Navigator.of(context).pop(true);
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          paymentPhase.value == 'checkingBalance'
                              ? 'btn_CheckingBalance'.tr
                              : paymentPhase.value != null
                                  ? 'inf_StatusUpdating'.tr
                                  : 'btn_PaySelected'.trParams({
                                      'count': '${selected.length}',
                                      'amount':
                                          formatNumber.formatMoney(total),
                                    }),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.light,
                              ),
                        ),
                        const SizedBox(width: 10),
                        FaIcon(
                          FontAwesomeIcons.circleCheck,
                          color: Theme.of(context).colorScheme.light,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
