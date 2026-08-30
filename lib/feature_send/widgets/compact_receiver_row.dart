import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_send/models/receiver_user_model.dart';

/// One-line recipient: @username · amount · remove
class CompactReceiverRow extends HookWidget {
  final ReceiverUserModel receiverUser;
  final bool showDivider;
  final void Function(int id, double amount) onAmountChanged;
  final VoidCallback onRemove;

  const CompactReceiverRow({
    super.key,
    required this.receiverUser,
    required this.onAmountChanged,
    required this.onRemove,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final amountController = useTextEditingController(
      text: receiverUser.amount > 0 ? receiverUser.amount.toString() : '',
    );
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.blue.withOpacity(0.12),
                child: Icon(Icons.person, size: 16, color: colors.blue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${receiverUser.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.dark,
                          ),
                    ),
                    if ('${receiverUser.firstName} ${receiverUser.lastName}'
                        .trim()
                        .isNotEmpty)
                      Text(
                        '${receiverUser.firstName} ${receiverUser.lastName}'
                            .trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.darkGray,
                              fontSize: 11,
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.dark,
                      ),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: '€ ',
                    prefixStyle: TextStyle(
                      color: colors.darkGray,
                      fontWeight: FontWeight.w500,
                    ),
                    hintText: '0',
                    hintStyle: TextStyle(color: colors.darkGray),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: colors.gray.withOpacity(0.25),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.blue, width: 1.5),
                    ),
                  ),
                  onChanged: (value) {
                    onAmountChanged(
                      receiverUser.id,
                      double.tryParse(value) ?? 0.0,
                    );
                  },
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close, size: 18, color: Colors.red.shade400),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, color: colors.gray.withOpacity(0.5)),
      ],
    );
  }
}
