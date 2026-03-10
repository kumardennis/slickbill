import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/constants.dart';
import 'package:slickbill/feature_nearby_transaction/widgets/big_input_amount.dart';
import 'package:slickbill/feature_self_create/widgets/input_field.dart';

class QuickShareScreen extends HookWidget {
  final ValueNotifier<String> qrData;
  final ValueNotifier<String?> publicInvoiceToken;
  final ValueNotifier<double> receiverUserAmount;
  final TextEditingController descriptionController;
  final TextEditingController dueDateController;
  final TextEditingController referenceNumberController;
  final ValueNotifier<String> category;
  final ValueNotifier<bool> isCreatingPublicInvoice;
  final Future<void> Function() createPublicInvoiceForQR;
  final Function(double) changeReceiverAmount;
  final VoidCallback startReadNfc;
  final VoidCallback scanQR;

  const QuickShareScreen({
    super.key,
    required this.qrData,
    required this.publicInvoiceToken,
    required this.receiverUserAmount,
    required this.descriptionController,
    required this.dueDateController,
    required this.referenceNumberController,
    required this.category,
    required this.isCreatingPublicInvoice,
    required this.createPublicInvoiceForQR,
    required this.changeReceiverAmount,
    required this.startReadNfc,
    required this.scanQR,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: _buildP2PTab(
        context: context,
        qrData: qrData,
        receiverUserAmount: receiverUserAmount,
        descriptionController: descriptionController,
        dueDateController: dueDateController,
        referenceNumberController: referenceNumberController,
        category: category,
        changeReceiverAmount: changeReceiverAmount,
        startReadNfc: startReadNfc,
        scanQR: scanQR,
      ),
    );
  }

  Widget _buildP2PTab({
    required BuildContext context,
    required ValueNotifier<String> qrData,
    required ValueNotifier<double> receiverUserAmount,
    required TextEditingController descriptionController,
    required TextEditingController dueDateController,
    required TextEditingController referenceNumberController,
    required ValueNotifier<String> category,
    required VoidCallback startReadNfc,
    required VoidCallback scanQR,
    required Function(double) changeReceiverAmount,
  }) {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 100;

    return Column(
      children: [
        // Info Banner
        Container(
          padding: EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.blue.withOpacity(0.1),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  color: Theme.of(context).colorScheme.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Exchange invoices offline with other SlickBill users via QR/NFC',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.dark,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Sticky QR Code
        if (!isKeyboardOpen)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.blue.withOpacity(0.15),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Scan with SlickBill app to create invoice',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.darkGray,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            Theme.of(context).colorScheme.blue.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: QrImageView(
                      data: qrData.value.isEmpty ? 'placeholder' : qrData.value,
                      version: QrVersions.auto,
                      size: 100,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.circle,
                        color: Theme.of(context).colorScheme.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Scrollable Form Content
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Amount Input
                  BigInputAmount(
                    changeReceiverAmount: changeReceiverAmount,
                  ),
                  SizedBox(height: 24),

                  InputField(
                    icon: Icons.description,
                    label: 'Description',
                    controller: descriptionController,
                  ),
                  SizedBox(height: 16),

                  InputField(
                    icon: Icons.calendar_today,
                    label: 'Due Date',
                    controller: dueDateController,
                    type: TextInputType.datetime,
                  ),
                  SizedBox(height: 16),

                  InputField(
                    icon: Icons.numbers,
                    label: 'Reference Number',
                    controller: referenceNumberController,
                  ),
                  SizedBox(height: 24),

                  // Category Dropdown
                  Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.dark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.light,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .darkGray
                            .withOpacity(0.2),
                      ),
                    ),
                    child: DropdownButton<String>(
                      value: category.value,
                      isExpanded: true,
                      underline: SizedBox(),
                      icon: Icon(Icons.arrow_drop_down),
                      items: Constants().categories.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          category.value = newValue;
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 32),

                  // Action Buttons Row
                  Row(
                    children: [
                      // Expanded(
                      //   child: ElevatedButton.icon(
                      //     onPressed: startReadNfc,
                      //     icon: FaIcon(FontAwesomeIcons.nfcSymbol, size: 18),
                      //     label: Text('Read NFC'),
                      //     style: ElevatedButton.styleFrom(
                      //       backgroundColor: Theme.of(context).colorScheme.blue,
                      //       foregroundColor: Colors.white,
                      //       padding: EdgeInsets.symmetric(vertical: 16),
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(12),
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: scanQR,
                          icon: FaIcon(FontAwesomeIcons.qrcode, size: 18),
                          label: Text('Scan QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.blue,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
