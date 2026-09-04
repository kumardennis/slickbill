import 'package:flutter/material.dart';
import 'package:slickbill/theme/sb_colors.dart';

class SbSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const SbSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SbSpace.md),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: SbColors.surfaceLowest,
        borderRadius: BorderRadius.circular(SbRadii.md),
        boxShadow: SbShadows.cardSoft,
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SbRadii.md),
        child: card,
      ),
    );
  }
}

class SbStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const SbStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(SbRadii.full),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class SbFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SbFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? SbColors.deepNavy : SbColors.surfaceHigh,
        borderRadius: BorderRadius.circular(SbRadii.full),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SbRadii.full),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? SbColors.onPrimary
                        : SbColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
