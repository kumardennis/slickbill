import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:slickbill/color_scheme.dart';
import '../feature_nearby_transaction/screens/make_nfc_available.dart';
import '../feature_send/utils/send_invoices_class.dart';
import '../feature_navigation/getx_controllers/navigation_controller.dart';

class GlobalReceiveService {
  static void showReceiveOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.light,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.gray.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Receive Slickbill',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.darkerBlue,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how you want to receive a bill',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.gray,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Options
            Row(
              children: [
                Expanded(
                  child: _buildReceiveOption(
                    context: context,
                    icon: FontAwesomeIcons.nfcSymbol,
                    title: 'NFC',
                    subtitle: 'inf_NFCInstruction'.tr,
                    color: Theme.of(context).colorScheme.blue,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MakeNfcAvailable(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildReceiveOption(
                    context: context,
                    icon: FontAwesomeIcons.qrcode,
                    title: 'QR Code',
                    subtitle: 'inf_QRInstruction'.tr,
                    color: Theme.of(context).colorScheme.turqouise,
                    onTap: () {
                      Navigator.pop(context);
                      _scanQR(context);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static Widget _buildReceiveOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.darkerBlue,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.gray,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static void _scanQR(BuildContext context) {
    bool isProcessing = false;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Scan QR Code'),
            backgroundColor: Theme.of(context).colorScheme.light,
            elevation: 0,
          ),
          body: MobileScanner(
            onDetect: (BarcodeCapture barcodes) {
              if (!isProcessing) {
                isProcessing = true;
                final scannedResult = _handleBarcode(barcodes);
                if (scannedResult != null) {
                  Navigator.of(context).pop();

                  // Show processing message
                  Get.snackbar(
                    'QR Code Scanned',
                    'Processing the slickbill...',
                    backgroundColor:
                        Theme.of(context).colorScheme.green.withOpacity(0.1),
                    colorText: Theme.of(context).colorScheme.green,
                  );

                  // Process the QR code
                  _createSlickbillFromQR(scannedResult);

                  Future.delayed(const Duration(milliseconds: 500), () {
                    isProcessing = false;
                  });
                } else {
                  isProcessing = false;
                }
              }
            },
          ),
        ),
      ),
    );
  }

  static String? _handleBarcode(BarcodeCapture barcodes) {
    return barcodes.barcodes.firstOrNull?.rawValue;
  }

  static Future<void> _createSlickbillFromQR(String result) async {
    try {
      final NavigationController navigationController = Get.find();
      SendInvoicesClass sendInvoicesClass = SendInvoicesClass();

      Map<String, dynamic> jsonObject = jsonDecode(result);

      await sendInvoicesClass.createReceivePrivateQRInvoice(
        jsonObject['description'],
        jsonObject['dueDate'],
        jsonObject['referenceNumber'],
        jsonObject['senderPrivateUserId'],
        jsonObject['amount'],
        jsonObject['category'],
      );

      navigationController.changeIndex(0);

      Get.snackbar(
        'Slickbill Received',
        'Received a slickbill from a user!',
        backgroundColor:
            Theme.of(Get.context!).colorScheme.green.withOpacity(0.1),
        colorText: Theme.of(Get.context!).colorScheme.green,
      );
    } catch (e) {
      print('Error parsing QR code: $e');
      Get.snackbar(
        'Error',
        'Failed to process the QR code.',
        backgroundColor:
            Theme.of(Get.context!).colorScheme.red.withOpacity(0.1),
        colorText: Theme.of(Get.context!).colorScheme.red,
      );
    }
  }
}
