import 'package:flutter/material.dart';
import 'package:slickbill/theme/sb_colors.dart';

class SbSegmentedControl extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<SbSegment> segments;

  const SbSegmentedControl({
    super.key,
    required this.index,
    required this.onChanged,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SbColors.surfaceLow,
        borderRadius: BorderRadius.circular(SbRadii.md),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              child: _SegmentButton(
                selected: i == index,
                segment: segments[i],
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class SbSegment {
  final String label;
  final IconData icon;

  const SbSegment({required this.label, required this.icon});
}

class _SegmentButton extends StatelessWidget {
  final bool selected;
  final SbSegment segment;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.selected,
    required this.segment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SbColors.surfaceLowest : Colors.transparent,
      elevation: selected ? 1 : 0,
      shadowColor: SbColors.deepNavy.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(SbRadii.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SbRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                segment.icon,
                size: 16,
                color: selected ? SbColors.deepNavy : SbColors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  segment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected
                            ? SbColors.deepNavy
                            : SbColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
