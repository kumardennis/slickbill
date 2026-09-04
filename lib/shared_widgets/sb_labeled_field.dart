import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/theme/sb_colors.dart';

class SbLabeledField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool boldValue;

  const SbLabeledField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.boldValue = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SbSpace.sm),
      decoration: BoxDecoration(
        color: SbColors.surfaceLow,
        borderRadius: BorderRadius.circular(SbRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: SbColors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: SbColors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: boldValue ? FontWeight.w700 : FontWeight.w400,
                  color: SbColors.onSurface,
                ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              filled: false,
              contentPadding: const EdgeInsets.only(top: 4, bottom: 2),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> pickDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final parsed = DateTime.tryParse(controller.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }
}
