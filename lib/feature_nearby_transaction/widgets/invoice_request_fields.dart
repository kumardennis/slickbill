import 'package:flutter/material.dart';
import 'package:slickbill/constants.dart';
import 'package:slickbill/shared_widgets/sb_labeled_field.dart';
import 'package:slickbill/theme/sb_colors.dart';

class InvoiceRequestFields extends StatelessWidget {
  final TextEditingController descriptionController;
  final TextEditingController dueDateController;
  final TextEditingController referenceNumberController;
  final String category;
  final ValueChanged<String> onCategoryChanged;

  const InvoiceRequestFields({
    super.key,
    required this.descriptionController,
    required this.dueDateController,
    required this.referenceNumberController,
    required this.category,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SbLabeledField(
          label: 'Description',
          icon: Icons.description_outlined,
          controller: descriptionController,
        ),
        const SizedBox(height: 8),
        SbLabeledField(
          label: 'Due Date',
          icon: Icons.calendar_today_rounded,
          controller: dueDateController,
          readOnly: true,
          onTap: () => SbLabeledField.pickDate(context, dueDateController),
        ),
        const SizedBox(height: 8),
        SbLabeledField(
          label: 'Reference Number',
          icon: Icons.tag_rounded,
          controller: referenceNumberController,
          hint: 'Optional invoice or ref #',
          boldValue: false,
        ),
        const SizedBox(height: 8),
        Container(
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
                  const Icon(
                    Icons.category_outlined,
                    size: 18,
                    color: SbColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Category',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: SbColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: category,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.expand_more_rounded,
                    color: SbColors.onSurfaceVariant,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: SbColors.onSurface,
                      ),
                  items: Constants().categories
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onCategoryChanged(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
