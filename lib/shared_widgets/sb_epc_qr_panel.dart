import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/shared_utils/epc_qr.dart';
import 'package:slickbill/shared_widgets/sb_qr_panel.dart';

/// Bank-app SCT QR for an unpaid bill. Hidden when IBAN or name is missing.
class SbEpcQrPanel extends StatelessWidget {
  final String? beneficiaryName;
  final String? iban;
  final double amountEur;
  final String? paymentMemo;
  final String? description;
  final double size;

  const SbEpcQrPanel({
    super.key,
    required this.beneficiaryName,
    required this.iban,
    required this.amountEur,
    this.paymentMemo,
    this.description,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final payload = EpcQrPayload.build(
      beneficiaryName: beneficiaryName ?? '',
      iban: iban ?? '',
      amountEur: amountEur,
      paymentMemo: paymentMemo,
      description: description,
    );
    if (payload == null) return const SizedBox.shrink();

    return SbQrPanel(
      data: payload,
      title: 'lbl_BankQr'.tr,
      caption: 'inf_BankQrCaption'.tr,
      size: size,
    );
  }
}
