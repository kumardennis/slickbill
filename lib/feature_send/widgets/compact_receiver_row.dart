import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:slickbill/feature_send/models/receiver_user_model.dart';
import 'package:slickbill/theme/sb_colors.dart';

/// One-line recipient: avatar · @username · amount · remove
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

  String get _initials {
    final first = receiverUser.firstName.trim();
    final last = receiverUser.lastName.trim();
    if (first.isEmpty && last.isEmpty) {
      final u = receiverUser.username;
      return u.isNotEmpty ? u[0].toUpperCase() : '?';
    }
    return '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final amountController = useTextEditingController(
      text: receiverUser.amount > 0 ? receiverUser.amount.toString() : '',
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: SbColors.surfaceLow,
          borderRadius: BorderRadius.circular(SbRadii.md),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: SbColors.primaryFixedDim.withValues(alpha: 0.45),
              child: Text(
                _initials,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: SbColors.deepNavy,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${receiverUser.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: SbColors.onSurface,
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
                            color: SbColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: SbColors.surfaceLowest,
                borderRadius: BorderRadius.circular(SbRadii.sm),
              ),
              child: Row(
                children: [
                  Text(
                    '€',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: SbColors.deepNavy,
                        ),
                  ),
                  SizedBox(
                    width: 40,
                    child: TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SbColors.deepNavy,
                          ),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: '0',
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onChanged: (value) {
                        onAmountChanged(
                          receiverUser.id,
                          double.tryParse(value) ?? 0.0,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(SbRadii.full),
              child: const SizedBox(
                width: 24,
                height: 24,
                child: Icon(Icons.close, size: 16, color: SbColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
