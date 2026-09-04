import 'package:flutter/material.dart';
import 'package:slickbill/theme/sb_colors.dart';

enum SbTrustBannerVariant { custody, p2p }

class SbTrustBanner extends StatelessWidget {
  final SbTrustBannerVariant variant;

  const SbTrustBanner({
    super.key,
    this.variant = SbTrustBannerVariant.custody,
  });

  @override
  Widget build(BuildContext context) {
    final isP2p = variant == SbTrustBannerVariant.p2p;
    final iconColor = isP2p ? SbColors.successGreen : SbColors.deepNavy;
    final iconBg = isP2p
        ? SbColors.successGreen.withValues(alpha: 0.1)
        : SbColors.deepNavy.withValues(alpha: 0.08);

    return Container(
      padding: const EdgeInsets.all(SbSpace.md),
      decoration: BoxDecoration(
        color: SbColors.surfaceLow,
        borderRadius: BorderRadius.circular(SbRadii.md),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isP2p ? Icons.verified_user_rounded : Icons.security_rounded,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: SbSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isP2p
                      ? 'Send invoices'
                      : 'Built in Tallinn for European Payments',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: SbColors.onSurface,
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  isP2p
                      ? '0% hidden fees.'
                      : 'Funds stay in your own account. SlickBills does not custody your funds.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SbColors.onSurfaceVariant,
                        fontSize: 11,
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
