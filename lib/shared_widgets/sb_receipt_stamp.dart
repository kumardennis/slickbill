import 'package:flutter/material.dart';
import 'package:slickbill/theme/sb_colors.dart';

/// Ink-stamp overlay for paid / overdue receipts.
class SbReceiptStamp extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  final double angle;
  final bool animate;

  const SbReceiptStamp({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 11,
    this.angle = 0.18,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final stamp = Transform.rotate(
      angle: angle,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.7,
          vertical: fontSize * 0.28,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.9), width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: fontSize * 0.14,
                height: 1,
              ),
        ),
      ),
    );

    if (!animate) {
      return IgnorePointer(child: stamp);
    }

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.35, end: 1),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Opacity(
            opacity: (2.1 - scale).clamp(0.55, 0.92),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: stamp,
      ),
    );
  }
}

class SbDashedDivider extends StatelessWidget {
  final Color color;

  const SbDashedDivider({
    super.key,
    this.color = SbColors.outlineVariant,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(color: color),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashSpace = 3.5;
    var x = 0.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    while (x < size.width) {
      final end = (x + dashWidth).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, 0.5), Offset(end, 0.5), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
