import 'package:flutter/material.dart';
import 'package:slickbill/theme/sb_colors.dart';

class SbQuickRequestCard extends StatelessWidget {
  final VoidCallback onNewRequest;
  final VoidCallback onViewHistory;

  const SbQuickRequestCard({
    super.key,
    required this.onNewRequest,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SbSpace.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SbColors.deepNavy, SbColors.primary],
        ),
        borderRadius: BorderRadius.circular(SbRadii.md),
        boxShadow: [
          BoxShadow(
            color: SbColors.primaryContainer.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: IgnorePointer(
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: SbColors.electricCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: SbColors.electricCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SbRadii.full),
                ),
                child: Text(
                  'Quick Request',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: SbColors.electricCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Every payment starts as a clear request.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: SbColors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'No guessing what it was for. Make the record right the first time for rent, coffee, or invoices.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SbColors.primaryFixedDim,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: onNewRequest,
                    style: FilledButton.styleFrom(
                      backgroundColor: SbColors.electricCyan,
                      foregroundColor: SbColors.deepNavy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SbRadii.sm),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'New Request',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onViewHistory,
                    style: TextButton.styleFrom(
                      foregroundColor: SbColors.onPrimary,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SbRadii.sm),
                      ),
                    ),
                    child: const Text(
                      'Statements',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
