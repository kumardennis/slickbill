import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:slickbill/feature_nearby_transaction/widgets/big_input_amount.dart';
import 'package:slickbill/feature_nearby_transaction/widgets/invoice_request_fields.dart';
import 'package:slickbill/shared_widgets/sb_trust_banner.dart';
import 'package:slickbill/theme/sb_colors.dart';

class QuickShareScreen extends HookWidget {
  final ValueNotifier<String> qrData;
  final TextEditingController descriptionController;
  final TextEditingController dueDateController;
  final TextEditingController referenceNumberController;
  final ValueNotifier<String> category;
  final Function(double) changeReceiverAmount;
  final VoidCallback scanQR;

  const QuickShareScreen({
    super.key,
    required this.qrData,
    required this.descriptionController,
    required this.dueDateController,
    required this.referenceNumberController,
    required this.category,
    required this.changeReceiverAmount,
    required this.scanQR,
  });

  @override
  Widget build(BuildContext context) {
    final qrExpanded = useState(false);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 80;

    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        children: [
          if (!keyboardOpen)
            Container(
              decoration: BoxDecoration(
                color: SbColors.surfaceLowest,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(SbRadii.md),
                  bottomRight: Radius.circular(SbRadii.md),
                ),
                boxShadow: SbShadows.cardSoft,
              ),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => qrExpanded.value = !qrExpanded.value,
                      borderRadius: qrExpanded.value
                          ? BorderRadius.zero
                          : const BorderRadius.only(
                              bottomLeft: Radius.circular(SbRadii.md),
                              bottomRight: Radius.circular(SbRadii.md),
                            ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.qr_code_rounded,
                              size: 18,
                              color: SbColors.deepNavy,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                qrExpanded.value
                                    ? 'Hide QR code'
                                    : 'Show QR code',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: SbColors.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            Icon(
                              qrExpanded.value
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: SbColors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild:
                        const SizedBox(width: double.infinity, height: 0),
                    secondChild: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        children: [
                          Text(
                            'Hold this up. They scan it in SlickBills — not Camera.',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: SbColors.onSurfaceVariant,
                                    ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(SbRadii.md),
                              border: Border.all(
                                color: SbColors.surfaceContainer,
                              ),
                            ),
                            child: QrImageView(
                              data: qrData.value.isEmpty
                                  ? 'slickbills'
                                  : qrData.value,
                              version: QrVersions.auto,
                              size: 140,
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
                        ],
                      ),
                    ),
                    crossFadeState: qrExpanded.value
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                    sizeCurve: Curves.easeInOut,
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(SbSpace.md),
                    decoration: BoxDecoration(
                      color: SbColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(SbRadii.md),
                      boxShadow: SbShadows.cardSoft,
                    ),
                    child: Column(
                      children: [
                        BigInputAmount(
                          changeReceiverAmount: changeReceiverAmount,
                        ),
                        const SizedBox(height: 8),
                        InvoiceRequestFields(
                          descriptionController: descriptionController,
                          dueDateController: dueDateController,
                          referenceNumberController:
                              referenceNumberController,
                          category: category.value,
                          onCategoryChanged: (value) =>
                              category.value = value,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: scanQR,
                      icon: const Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 20,
                      ),
                      label: const Text('Scan a SlickBills QR'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SbTrustBanner(
                    variant: SbTrustBannerVariant.p2p,
                    title: 'SlickBills to SlickBills',
                    subtitle:
                        'This QR stays in the app. No public link, no browser page.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
