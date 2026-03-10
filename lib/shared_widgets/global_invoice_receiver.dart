import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/models/invoice_model.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
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
              'Receive via QR, more options will be coming soon!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.gray,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Options
            Row(
              children: [
                // Expanded(
                //   child: _buildReceiveOption(
                //     context: context,
                //     icon: FontAwesomeIcons.nfcSymbol,
                //     title: 'NFC',
                //     subtitle: 'inf_NFCInstruction'.tr,
                //     color: Theme.of(context).colorScheme.blue,
                //     onTap: () {
                //       Navigator.pop(context);
                //       Navigator.push(
                //         context,
                //         MaterialPageRoute(
                //           builder: (context) => const MakeNfcAvailable(),
                //         ),
                //       );
                //     },
                //   ),
                // ),
                // const SizedBox(width: 16),
                Expanded(
                  child: _buildReceiveOption(
                    context: context,
                    icon: FontAwesomeIcons.qrcode,
                    title: 'QR Code',
                    subtitle: 'inf_QRInstruction'.tr,
                    color: Theme.of(context).colorScheme.turqouise,
                    onTap: () {
                      final rootNavigator =
                          Navigator.of(context, rootNavigator: true);
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scanQR(rootNavigator.context);
                      });
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

    final scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );

    final navigator = Navigator.of(context, rootNavigator: true);

    navigator
        .push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Scan QR Code'),
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: Stack(
            children: [
              // Camera Preview
              MobileScanner(
                controller: scannerController,
                onDetect: (BarcodeCapture barcodes) async {
                  if (isProcessing) return;
                  isProcessing = true;

                  final scannedResult = _handleBarcode(barcodes);

                  await scannerController.stop();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }

                  if (scannedResult == null) return;

                  // Show processing message
                  Get.snackbar(
                    'QR Code Scanned',
                    'Processing the slickbill...',
                    backgroundColor:
                        Theme.of(context).colorScheme.green.withOpacity(0.1),
                    colorText: Theme.of(context).colorScheme.green,
                  );

                  // Process the QR code
                  await _createSlickbillFromQR(scannedResult);
                },
              ),

              // Overlay with scan frame
              CustomPaint(
                painter: _ScannerOverlayPainter(),
                child: Container(),
              ),

              // Instructions
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Position QR code within frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // // Flash toggle
              // Positioned(
              //   bottom: 40,
              //   left: 0,
              //   right: 0,
              //   child: Center(
              //     child: IconButton(
              //       icon: ValueListenableBuilder(
              //         valueListenable: scannerController.torchState,
              //         builder: (context, state, child) {
              //           return Icon(
              //             state == TorchState.off
              //                 ? Icons.flash_off
              //                 : Icons.flash_on,
              //             color: Colors.white,
              //             size: 32,
              //           );
              //         },
              //       ),
              //       onPressed: () => scannerController.toggleTorch(),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    )
        .then((_) {
      // Cleanup if user navigates back
      scannerController.dispose();
    });
  }

  static String? _handleBarcode(BarcodeCapture barcodes) {
    // ✅ Check if it's a URL (public invoice)
    final rawValue = barcodes.barcodes.firstOrNull?.rawValue;
    if (rawValue == null) return null;

    if (rawValue.startsWith('http://') || rawValue.startsWith('https://')) {
      try {
        final uri = Uri.parse(rawValue);

        // Check if it's an invoice URL
        if (uri.pathSegments.contains('invoice') &&
            uri.pathSegments.length >= 2) {
          final tokenIndex = uri.pathSegments.indexOf('invoice') + 1;
          final token = uri.pathSegments[tokenIndex];

          print('✅ Public invoice detected: $token');

          // Navigate to public invoice page
          Get.toNamed('/bill/$token');

          return null; // Prevent further processing
        }
      } catch (e) {
        print('❌ Error parsing URL: $e');
      }
    }

    return barcodes.barcodes.firstOrNull?.rawValue;
  }

  static Future<InvoiceModel?> _createSlickbillFromQR(String result) async {
    try {
      final NavigationController navigationController = Get.find();
      SendInvoicesClass sendInvoicesClass = SendInvoicesClass();
      ReceivedInvoicesClass receivedInvoicesClass = ReceivedInvoicesClass();

      if (result.startsWith('https://app.slickbills.com/bill/')) {
        // Extract the public token from the URL
        final publicToken = result.split('/bill/').last;

        print(
            '📱 Scanned public invoice link, navigating to: /bill/$publicToken');

        // ✅ Just navigate using deep link - app is already installed!
        Get.toNamed('/bill/$publicToken');
        return null;
      }

      Map<String, dynamic> jsonObject = jsonDecode(result);

      final invoiceId = await sendInvoicesClass.createReceivePrivateQRInvoice(
        jsonObject['description'],
        jsonObject['dueDate'],
        jsonObject['referenceNumber'],
        jsonObject['senderPrivateUserId'],
        jsonObject['senderName'],
        jsonObject['amount'],
        jsonObject['category'],
      );

      if (invoiceId == null) {
        throw Exception('Failed to create slickbill from QR code.');
      }

      final invoices = await receivedInvoicesClass.getPrivateReceivedInvoices(
          id: int.parse(invoiceId));

      navigationController.changeIndex(0);

      Get.snackbar(
        'Slickbill Received',
        'Received a slickbill from a user!',
        backgroundColor:
            Theme.of(Get.context!).colorScheme.green.withOpacity(0.1),
        colorText: Theme.of(Get.context!).colorScheme.green,
      );

      return invoices?.first;
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
    return null;
  }
}

// Add the overlay painter class at the end of the file
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 2;

    // Draw overlay with transparent center
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize),
        Radius.circular(20),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw corner brackets
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + cornerLength),
      Offset(scanAreaLeft, scanAreaTop),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop),
      Offset(scanAreaLeft + cornerLength, scanAreaTop),
      borderPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + cornerLength),
      borderPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize),
      borderPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength,
          scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize,
          scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
