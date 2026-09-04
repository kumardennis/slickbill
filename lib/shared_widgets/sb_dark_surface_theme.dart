import 'package:flutter/material.dart';
import 'package:slickbill/theme/sb_colors.dart';

const double kInvoiceSheetHeightFactor = 0.82;
const Color _onDark = Colors.white;
const Color _mutedOnDark = Color(0xFFDDE4E5);
const Color _labelOnDark = Color(0xFFB8C5CC);

ThemeData darkInvoiceSheetTheme(BuildContext context) {
  final theme = Theme.of(context);
  return theme.copyWith(
    brightness: Brightness.dark,
    textTheme: theme.textTheme.apply(
      bodyColor: _onDark,
      displayColor: _onDark,
    ).copyWith(
      bodySmall: theme.textTheme.bodySmall?.copyWith(color: _labelOnDark),
    ),
    colorScheme: theme.colorScheme.copyWith(
      brightness: Brightness.dark,
      onSurface: _onDark,
      onSurfaceVariant: _mutedOnDark,
      outline: _labelOnDark,
      outlineVariant: const Color(0xFF8A9AA3),
      surface: _onDark,
    ),
    iconTheme: const IconThemeData(color: _onDark),
    dividerColor: _labelOnDark,
  );
}

class SbDarkSurfaceTheme extends StatelessWidget {
  final WidgetBuilder builder;

  const SbDarkSurfaceTheme({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: darkInvoiceSheetTheme(context),
      child: Builder(builder: builder),
    );
  }
}

Future<T?> showInvoiceSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    enableDrag: true,
    isDismissible: true,
    backgroundColor: SbColors.deepNavy,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SbRadii.lg),
      ),
    ),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final height = (media.size.height - media.padding.top) *
          kInvoiceSheetHeightFactor;
      return SizedBox(
        height: height,
        child: Theme(
          data: darkInvoiceSheetTheme(sheetContext),
          child: Builder(builder: builder),
        ),
      );
    },
  );
}
