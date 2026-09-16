import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:slickbill/theme/sb_colors.dart';

enum SbInvoiceStatusMark { unpaid, processing, paid, overdue }

/// Pauses descendant tickers while this box is off-screen in a scroll view.
class SbViewportTicker extends StatefulWidget {
  final Widget child;

  const SbViewportTicker({super.key, required this.child});

  @override
  State<SbViewportTicker> createState() => _SbViewportTickerState();
}

class _SbViewportTickerState extends State<SbViewportTicker> {
  ScrollPosition? _position;
  bool _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (!identical(_position, next)) {
      _position?.removeListener(_onScroll);
      _position = next;
      _position?.addListener(_onScroll);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final visible = _computeVisible();
    if (visible != _visible) {
      setState(() => _visible = visible);
    }
  }

  bool _computeVisible() {
    final object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize || !object.attached) {
      return _visible;
    }
    final viewport = RenderAbstractViewport.maybeOf(object);
    if (viewport == null) return true;
    try {
      final itemOffset = viewport.getOffsetToReveal(object, 0).offset;
      final itemExtent = object.size.height;
      final pixels = _position?.pixels ?? 0;
      final vpExtent = _position?.viewportDimension ?? 0;
      return itemOffset < pixels + vpExtent && itemOffset + itemExtent > pixels;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(enabled: _visible, child: widget.child);
  }
}

class SbStatusMark extends StatelessWidget {
  final SbInvoiceStatusMark mark;
  final double size;

  const SbStatusMark({
    super.key,
    required this.mark,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (mark) {
      SbInvoiceStatusMark.paid => SbColors.successGreen,
      SbInvoiceStatusMark.processing => SbColors.electricCyan,
      SbInvoiceStatusMark.overdue => SbColors.error,
      SbInvoiceStatusMark.unpaid => SbColors.warningAmber,
    };
    final icon = switch (mark) {
      SbInvoiceStatusMark.paid => Icons.verified_rounded,
      SbInvoiceStatusMark.processing => Icons.hourglass_top_rounded,
      SbInvoiceStatusMark.overdue => Icons.warning_amber_rounded,
      SbInvoiceStatusMark.unpaid => Icons.receipt_long_rounded,
    };

    if (mark == SbInvoiceStatusMark.processing) {
      return _ProcessingPulse(color: color, icon: icon, size: size);
    }

    if (mark == SbInvoiceStatusMark.unpaid) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _DashedCirclePainter(
                color: color.withValues(alpha: 0.75),
              ),
            ),
            Icon(icon, size: size * 0.5, color: color),
          ],
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

class _ProcessingPulse extends StatefulWidget {
  final Color color;
  final IconData icon;
  final double size;

  const _ProcessingPulse({
    required this.color,
    required this.icon,
    required this.size,
  });

  @override
  State<_ProcessingPulse> createState() => _ProcessingPulseState();
}

class _ProcessingPulseState extends State<_ProcessingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_controller.value);
          final ring = size * (1 + 0.18 * t);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: ring,
                height: ring,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.4 * (1 - t)),
                    width: 1.4,
                  ),
                ),
              ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: child,
              ),
            ],
          );
        },
        child: Icon(
          widget.icon,
          size: size * 0.5,
          color: widget.color,
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;

  _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dashCount = 18;
    const sweep = 2 * 3.1415926535 / dashCount;
    const dashSweep = sweep * 0.55;
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * sweep, dashSweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
