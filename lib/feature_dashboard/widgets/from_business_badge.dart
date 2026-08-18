import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';

class FromBusinessBadge extends StatelessWidget {
  const FromBusinessBadge({super.key, this.isBusiness = true});

  final bool isBusiness;

  @override
  Widget build(BuildContext context) {
    final color = isBusiness
        ? Theme.of(context).colorScheme.yellow
        : Theme.of(context).colorScheme.lightGreen;

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
            isBusiness ? 'lbl_Business'.tr : 'lbl_Private'.tr,
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
