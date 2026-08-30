import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/models/merchant_check_in_session_model.dart';
import 'package:slickbill/feature_loyalty/repos/merchant_cashier_repo.dart';
import 'package:slickbill/feature_loyalty/utils/loyalty_badge.dart';

Future<bool> showMerchantSessionBillSheet({
  required MerchantCheckInSessionModel session,
  required MerchantCashierRepo repo,
}) async {
  final context = Get.context;
  if (context == null) return false;

  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _MerchantSessionBillSheet(
      session: session,
      repo: repo,
    ),
  );

  return sent == true;
}

class _MerchantSessionBillSheet extends HookWidget {
  final MerchantCheckInSessionModel session;
  final MerchantCashierRepo repo;

  const _MerchantSessionBillSheet({
    required this.session,
    required this.repo,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final amounts = useState<Map<String, double>>({});
    final isSending = useState(false);
    final error = useState<String?>(null);

    double totalAmount() {
      return amounts.value.values.fold(0.0, (sum, value) => sum + value);
    }

    int billedCount() {
      return amounts.value.values.where((value) => value > 0).length;
    }

    Future<void> sendBills() async {
      error.value = null;
      if (billedCount() == 0) {
        error.value = 'err_LoyaltyBillAmountRequired'.tr;
        return;
      }

      isSending.value = true;
      try {
        await repo.billSessionMembers(
          sessionId: session.sessionId,
          amountsByMemberToken: amounts.value,
        );
        if (context.mounted) {
          Get.back(result: true);
          Get.snackbar(
            'inf_SessionBillSent'.tr,
            billedCount() == 1
                ? 'inf_SessionBillSentSingle'.tr
                : 'inf_SessionBillSentGroup'.trParams({
                    'count': '${billedCount()}',
                  }),
          );
        }
      } catch (e) {
        error.value = e is String ? e : e.toString();
      } finally {
        isSending.value = false;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: colors.light,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.gray.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'hd_BillVisit'.tr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.dark,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              session.sessionToken.isNotEmpty
                  ? session.sessionToken
                  : 'lbl_ThisUser'.tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.darkGray,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'lbl_BillVisitHint'.tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.darkGray,
                  ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: session.members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final member = session.members[index];
                  return _MemberAmountRow(
                    memberToken: member.memberToken,
                    loyaltyBadge: member.loyaltyBadge,
                    initialAmount: amounts.value[member.memberToken] ?? 0,
                    onAmountChanged: (value) {
                      final next = Map<String, double>.from(amounts.value);
                      if (value > 0) {
                        next[member.memberToken] = value;
                      } else {
                        next.remove(member.memberToken);
                      }
                      amounts.value = next;
                    },
                  );
                },
              ),
            ),
            if (error.value != null) ...[
              const SizedBox(height: 12),
              Text(
                error.value!,
                style: TextStyle(color: colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'lbl_BillVisitTotal'.tr,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.darkGray,
                      ),
                ),
                const Spacer(),
                Text(
                  '€ ${totalAmount().toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.dark,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSending.value ? null : () => Get.back(),
                    child: Text('btn_Cancel'.tr),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: isSending.value ? null : sendBills,
                    child: isSending.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('btn_SendBills'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberAmountRow extends HookWidget {
  final String memberToken;
  final String loyaltyBadge;
  final double initialAmount;
  final ValueChanged<double> onAmountChanged;

  const _MemberAmountRow({
    required this.memberToken,
    required this.loyaltyBadge,
    required this.initialAmount,
    required this.onAmountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = useTextEditingController(
      text: initialAmount > 0 ? initialAmount.toString() : '',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.gray.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memberToken,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.dark,
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: loyaltyBadgeColor(context, loyaltyBadge)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    loyaltyBadgeLabel(loyaltyBadge),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: loyaltyBadgeColor(context, loyaltyBadge),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.dark,
                  ),
              decoration: InputDecoration(
                isDense: true,
                prefixText: '€ ',
                prefixStyle: TextStyle(
                  color: colors.darkGray,
                  fontWeight: FontWeight.w500,
                ),
                hintText: '0',
                hintStyle: TextStyle(color: colors.darkGray),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                filled: true,
                fillColor: colors.gray.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.blue, width: 1.5),
                ),
              ),
              onChanged: (value) {
                onAmountChanged(double.tryParse(value) ?? 0);
              },
            ),
          ),
        ],
      ),
    );
  }
}
