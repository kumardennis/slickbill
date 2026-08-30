import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/models/merchant_check_in_session_model.dart';
import 'package:slickbill/feature_loyalty/utils/loyalty_badge.dart';

class MerchantOpenSessionRow extends StatelessWidget {
  final MerchantCheckInSessionModel session;
  final VoidCallback onClose;
  final VoidCallback? onBill;
  final bool isClosing;
  final bool isBilling;

  const MerchantOpenSessionRow({
    super.key,
    required this.session,
    required this.onClose,
    this.onBill,
    this.isClosing = false,
    this.isBilling = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.green.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.green.withOpacity(0.12),
                child: Icon(Icons.groups_outlined, color: colors.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.sessionToken.isNotEmpty
                          ? session.sessionToken
                          : 'lbl_ThisUser'.tr,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colors.dark,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'lbl_VisitMemberCount'.trParams({
                        'count': '${session.memberCount}',
                      }),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.darkGray,
                          ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: isClosing ? null : onClose,
                child: isClosing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('btn_CloseSession'.tr),
              ),
            ],
          ),
          if (session.members.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...session.members.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.memberToken,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.dark,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: loyaltyBadgeColor(
                          context,
                          member.loyaltyBadge,
                        ).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        loyaltyBadgeLabel(member.loyaltyBadge),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: loyaltyBadgeColor(
                                context,
                                member.loyaltyBadge,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed:
                    onBill == null || isClosing || isBilling ? null : onBill,
                child: isBilling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('btn_BillVisit'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
