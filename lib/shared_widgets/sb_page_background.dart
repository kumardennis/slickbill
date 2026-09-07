import 'package:flutter/material.dart';
import 'package:slickbill/theme/sb_colors.dart';

/// Soft page atmosphere: vertical wash plus two faint light pools.
class SbPageBackground extends StatelessWidget {
  final Widget child;

  const SbPageBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: SbGradients.page),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      SbColors.electricCyan.withValues(alpha: 0.08),
                      SbColors.electricCyan.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: 80,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      SbColors.primaryContainer.withValues(alpha: 0.05),
                      SbColors.primaryContainer.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
