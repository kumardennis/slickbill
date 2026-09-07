import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/theme/sb_colors.dart';

/// Whole euros stay heavy; cents recede so the amount is easy to scan.
class SbMoneyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final Color? color;
  final int maxLines;

  const SbMoneyText({
    super.key,
    required this.amount,
    this.style,
    this.color,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.headlineSmall)!.copyWith(
      color: color ?? style?.color ?? SbColors.onSurface,
    );
    final parts = _split(amount);
    final fractionSize = (base.fontSize ?? 18) * 0.72;

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: parts.prefix),
          TextSpan(text: parts.whole),
          TextSpan(
            text: parts.fraction,
            style: base.copyWith(
              fontSize: fractionSize,
              letterSpacing: 0,
              height: 1,
            ),
          ),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  static _MoneyParts _split(double value) {
    final format = NumberFormat.currency(symbol: '', decimalDigits: 2);
    final formatted = format.format(value).trim();
    final sep = format.symbols.DECIMAL_SEP;
    final index = formatted.lastIndexOf(sep);
    final whole = index >= 0 ? formatted.substring(0, index).trim() : formatted;
    final cents = index >= 0
        ? formatted.substring(index + sep.length).replaceAll(RegExp(r'\D'), '')
        : '00';

    return _MoneyParts(
      prefix: '€\u00a0',
      whole: whole.isEmpty ? '0' : whole,
      fraction: '$sep${cents.padLeft(2, '0')}',
    );
  }
}

class _MoneyParts {
  final String prefix;
  final String whole;
  final String fraction;

  const _MoneyParts({
    required this.prefix,
    required this.whole,
    required this.fraction,
  });
}
