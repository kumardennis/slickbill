import 'package:flutter/material.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/theme/sb_colors.dart';

class StatisticsCard extends StatelessWidget {
  final double? pendingAmount;
  final double? paidAmount;
  final String pendingLabel;
  final String paidLabel;
  final String? pendingSubtitle;
  final String? paidSubtitle;

  const StatisticsCard({
    super.key,
    this.pendingAmount,
    this.paidAmount,
    required this.pendingLabel,
    required this.paidLabel,
    this.pendingSubtitle,
    this.paidSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    final formatNumber = FormatNumber();
    final pendingZero = (pendingAmount ?? 0) <= 0;
    final paidZero = (paidAmount ?? 0) <= 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _OverviewTile(
            title: pendingLabel,
            amount: pendingAmount != null
                ? formatNumber.formatMoney(pendingAmount!)
                : '€0.00',
            subtitle: pendingSubtitle ??
                (pendingZero ? 'All clear' : null),
            subtitleColor: SbColors.warningAmber,
            icon: Icons.schedule_rounded,
            iconColor: SbColors.warningAmber,
          ),
        ),
        const SizedBox(width: SbSpace.sm),
        Expanded(
          child: _OverviewTile(
            title: paidLabel,
            amount: paidAmount != null
                ? formatNumber.formatMoney(paidAmount!)
                : '€0.00',
            subtitle: paidSubtitle ??
                (paidZero ? 'All settled up' : null),
            subtitleColor: SbColors.onSurfaceVariant,
            icon: Icons.check_circle_rounded,
            iconColor: SbColors.successGreen,
          ),
        ),
      ],
    );
  }
}

class _OverviewTile extends StatelessWidget {
  final String title;
  final String amount;
  final String? subtitle;
  final Color subtitleColor;
  final IconData icon;
  final Color iconColor;

  const _OverviewTile({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.subtitleColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SbSpace.md),
      decoration: BoxDecoration(
        color: SbColors.surfaceLowest,
        borderRadius: BorderRadius.circular(SbRadii.md),
        boxShadow: SbShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: SbColors.onSurfaceVariant,
                      ),
                ),
              ),
              Icon(icon, size: 20, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: SbColors.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? ' ',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: subtitle == null
                      ? Colors.transparent
                      : subtitleColor,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}
