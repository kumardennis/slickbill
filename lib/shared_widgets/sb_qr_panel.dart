import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:slickbill/theme/sb_colors.dart';

/// Quiet, scannable QR. Square modules, navy ink, no glow.
class SbQrPanel extends StatelessWidget {
  final String data;
  final String title;
  final String caption;
  final double size;
  final Widget? footer;

  const SbQrPanel({
    super.key,
    required this.data,
    required this.title,
    required this.caption,
    this.size = 200,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SbSpace.md),
      decoration: BoxDecoration(
        color: SbColors.surfaceLowest,
        borderRadius: BorderRadius.circular(SbRadii.md),
        boxShadow: SbShadows.cardSoft,
      ),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: SbColors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: SbSpace.md),
          Container(
            padding: const EdgeInsets.all(SbSpace.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(SbRadii.md),
              border: Border.all(color: SbColors.surfaceContainer),
            ),
            child: QrImageView(
              data: data.isEmpty ? 'slickbills' : data,
              version: QrVersions.auto,
              size: size,
              gapless: true,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: SbColors.deepNavy,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: SbColors.deepNavy,
              ),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: SbSpace.sm),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SbColors.onSurfaceVariant,
                  fontSize: 12,
                ),
          ),
          if (footer != null) ...[
            const SizedBox(height: SbSpace.md),
            footer!,
          ],
        ],
      ),
    );
  }
}
