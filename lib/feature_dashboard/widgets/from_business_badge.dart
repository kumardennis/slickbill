import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';

enum BusinessBadgePerspective {
  /// Received / counterparty: invoice came from a business.
  fromBusiness,

  /// Sent: you issued this invoice as your business.
  sentAsBusiness,

  /// Profile / account mode badge.
  account,
}

class FromBusinessBadge extends StatelessWidget {
  const FromBusinessBadge({
    super.key,
    this.isBusiness = true,
    this.perspective = BusinessBadgePerspective.fromBusiness,
  });

  final bool isBusiness;
  final BusinessBadgePerspective perspective;

  @override
  Widget build(BuildContext context) {
    final color = isBusiness
        ? Theme.of(context).colorScheme.warningAmber
        : Theme.of(context).colorScheme.successGreen;

    final label = !isBusiness
        ? 'lbl_Private'.tr
        : switch (perspective) {
            BusinessBadgePerspective.sentAsBusiness =>
              'lbl_SentAsBusiness'.tr,
            BusinessBadgePerspective.fromBusiness ||
            BusinessBadgePerspective.account =>
              'lbl_Business'.tr,
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBusiness ? Icons.business : Icons.person,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}
