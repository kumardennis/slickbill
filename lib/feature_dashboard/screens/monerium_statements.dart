import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/payment_setup_controller.dart';
import 'package:slickbill/feature_dashboard/models/monerium_statement_order.dart';
import 'package:slickbill/feature_dashboard/screens/profile.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:slickbill/shared_widgets/sb_surface_card.dart';
import 'package:slickbill/theme/sb_colors.dart';
import 'package:url_launcher/url_launcher.dart';

enum _DirectionFilter { all, incoming, outgoing }

enum _StateFilter { all, processed, pending }

class MoneriumStatements extends HookWidget {
  const MoneriumStatements({super.key});

  @override
  Widget build(BuildContext context) {
    final userController = Get.find<UserController>();

    final isLoading = useState(true);
    final needsSetup = useState(false);
    final error = useState<String?>(null);
    final orders = useState<List<MoneriumStatementOrder>>([]);
    final direction = useState(_DirectionFilter.all);
    final stateFilter = useState(_StateFilter.all);
    final formatNumber = FormatNumber();

    Future<void> load() async {
      final userId =
          PaymentSetupController.resolveMoneriumUserId(userController.user.value);
      if (userId.isEmpty || userId == '0') {
        orders.value = [];
        needsSetup.value = true;
        error.value = null;
        isLoading.value = false;
        return;
      }

      final sessionReady = await MoneriumService.hasActiveSession(userId: userId);
      if (!sessionReady) {
        orders.value = [];
        needsSetup.value = true;
        error.value = null;
        isLoading.value = false;
        return;
      }

      needsSetup.value = false;

      isLoading.value = true;
      error.value = null;
      try {
        final response = await MoneriumService.getOrders(userId: userId);
        final rows = MoneriumService.extractOrdersList(response)
            .map(MoneriumStatementOrder.fromJson)
            .where((order) => order.id.isNotEmpty)
            .toList()
          ..sort((a, b) {
            final aDate = a.placedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.placedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        orders.value = rows;
      } catch (e) {
        error.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, []);

    final visible = orders.value.where((order) {
      if (direction.value == _DirectionFilter.incoming && !order.isIncoming) {
        return false;
      }
      if (direction.value == _DirectionFilter.outgoing && !order.isOutgoing) {
        return false;
      }
      if (stateFilter.value == _StateFilter.processed && !order.isProcessed) {
        return false;
      }
      if (stateFilter.value == _StateFilter.pending && !order.isPending) {
        return false;
      }
      return true;
    }).toList();

    final grouped = <String, List<MoneriumStatementOrder>>{};
    for (final order in visible) {
      final key = order.placedAt != null
          ? DateFormat('EEE, d MMM yyyy').format(order.placedAt!)
          : 'lbl_AllTime'.tr;
      grouped.putIfAbsent(key, () => []).add(order);
    }

    return Scaffold(
      backgroundColor: SbColors.surface,
      appBar: const CustomAppbar(
        title: 'hd_Statements',
        appbarIcon: null,
        showSettings: false,
      ),
      body: RefreshIndicator(
        onRefresh: load,
        color: SbColors.deepNavy,
        child: needsSetup.value && !isLoading.value
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 48),
                  Text(
                    'lbl_StatementsNeedMonerium'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: SbColors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton(
                      onPressed: () => Get.to(() => const Profile()),
                      style: FilledButton.styleFrom(
                        backgroundColor: SbColors.deepNavy,
                      ),
                      child: Text('btn_OpenProfile'.tr),
                    ),
                  ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        SbFilterPill(
                          label: 'lbl_All'.tr,
                          selected: direction.value == _DirectionFilter.all,
                          onTap: () => direction.value = _DirectionFilter.all,
                        ),
                        SbFilterPill(
                          label: 'lbl_Incoming'.tr,
                          selected:
                              direction.value == _DirectionFilter.incoming,
                          onTap: () =>
                              direction.value = _DirectionFilter.incoming,
                        ),
                        SbFilterPill(
                          label: 'lbl_Outgoing'.tr,
                          selected:
                              direction.value == _DirectionFilter.outgoing,
                          onTap: () =>
                              direction.value = _DirectionFilter.outgoing,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        SbFilterPill(
                          label: 'lbl_Processed'.tr,
                          selected:
                              stateFilter.value == _StateFilter.processed,
                          onTap: () => stateFilter.value =
                              stateFilter.value == _StateFilter.processed
                                  ? _StateFilter.all
                                  : _StateFilter.processed,
                        ),
                        SbFilterPill(
                          label: 'lbl_Pending'.tr,
                          selected: stateFilter.value == _StateFilter.pending,
                          onTap: () => stateFilter.value =
                              stateFilter.value == _StateFilter.pending
                                  ? _StateFilter.all
                                  : _StateFilter.pending,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isLoading.value && orders.value.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (error.value != null)
                    Text(
                      'err_StatementsLoadFailed'.tr,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: SbColors.error,
                          ),
                    )
                  else if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Text(
                        'lbl_NoStatements'.tr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: SbColors.onSurfaceVariant,
                            ),
                      ),
                    )
                  else
                    ...grouped.entries.expand((entry) {
                      return [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 8),
                          child: Text(
                            entry.key,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: SbColors.onSurfaceVariant,
                                ),
                          ),
                        ),
                        ...entry.value.map(
                          (order) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _StatementRow(
                              order: order,
                              amountLabel: formatNumber.formatMoney(order.amount),
                            ),
                          ),
                        ),
                      ];
                    }),
                ],
              ),
      ),
    );
  }
}

class _StatementRow extends StatelessWidget {
  final MoneriumStatementOrder order;
  final String amountLabel;

  const _StatementRow({
    required this.order,
    required this.amountLabel,
  });

  @override
  Widget build(BuildContext context) {
    final accent = order.isRejected
        ? SbColors.error
        : order.isIncoming
            ? SbColors.successGreen
            : SbColors.deepNavy;
    final signedAmount = order.isOutgoing ? '-$amountLabel' : amountLabel;
    final title = order.counterpartName?.trim().isNotEmpty == true
        ? order.counterpartName!
        : (order.isIncoming ? 'lbl_Incoming'.tr : 'lbl_Outgoing'.tr);
    final statusLabel = order.isProcessed
        ? 'lbl_Processed'.tr
        : order.isRejected
            ? 'lbl_Rejected'.tr
            : 'lbl_Pending'.tr;

    return SbSurfaceCard(
      onTap: () => Get.to(() => _StatementDetail(order: order)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              order.isIncoming
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              size: 18,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: SbColors.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (order.memo != null && order.memo!.isNotEmpty) order.memo!,
                    statusLabel,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SbColors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            signedAmount,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatementDetail extends StatelessWidget {
  final MoneriumStatementOrder order;

  const _StatementDetail({required this.order});

  @override
  Widget build(BuildContext context) {
    final formatNumber = FormatNumber();
    final accent = order.isIncoming ? SbColors.successGreen : SbColors.deepNavy;

    return Scaffold(
      backgroundColor: SbColors.surface,
      appBar: const CustomAppbar(
        title: 'hd_Statements',
        appbarIcon: null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            formatNumber.formatMoney(order.amount),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            order.isIncoming ? 'lbl_Incoming'.tr : 'lbl_Outgoing'.tr,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SbColors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          _DetailTile(
            label: 'lbl_TrackStatus'.tr,
            value: order.isProcessed
                ? 'lbl_Processed'.tr
                : order.isRejected
                    ? 'lbl_Rejected'.tr
                    : 'lbl_Pending'.tr,
          ),
          if (order.placedAt != null)
            _DetailTile(
              label: 'lbl_Date'.tr,
              value: DateFormat('EEE, d MMM yyyy • HH:mm').format(order.placedAt!),
            ),
          if (order.counterpartName != null)
            _DetailTile(
              label: 'lbl_Counterpart'.tr,
              value: order.counterpartName!,
            ),
          if (order.counterpartIban != null)
            _DetailTile(
              label: 'IBAN',
              value: order.counterpartIban!,
              copyable: true,
            ),
          if (order.memo != null)
            _DetailTile(
              label: 'lbl_Memo'.tr,
              value: order.memo!,
            ),
          if (order.txHash != null)
            _DetailTile(
              label: 'lbl_TxHash'.tr,
              value: order.txHash!,
              copyable: true,
              onOpen: () => _openExplorer(order),
            ),
        ],
      ),
    );
  }

  Future<void> _openExplorer(MoneriumStatementOrder order) async {
    final hash = order.txHash?.trim();
    if (hash == null || hash.isEmpty) return;
    final chain = (order.chain ?? '').toLowerCase();
    final host = switch (chain) {
      'base' => 'basescan.org',
      'ethereum' || 'mainnet' => 'etherscan.io',
      _ => 'polygonscan.com',
    };
    final uri = Uri.parse('https://$host/tx/$hash');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final VoidCallback? onOpen;

  const _DetailTile({
    required this.label,
    required this.value,
    this.copyable = false,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SbSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: SbColors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: SbColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (copyable)
                  IconButton(
                    tooltip: 'inf_Copied'.tr,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      Get.snackbar('inf_Copied'.tr, value);
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                if (onOpen != null)
                  IconButton(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
