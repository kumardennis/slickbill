import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/constants.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:slickbill/feature_nearby_transaction/widgets/big_input_amount.dart';
import 'package:slickbill/feature_self_create/widgets/input_field.dart';
import 'package:slickbill/feature_self_create/widgets/input_field_amount.dart';
import 'package:slickbill/feature_send/models/receiver_user_model.dart';
import 'package:slickbill/feature_send/models/users_by_username_model.dart';
import 'package:slickbill/feature_send/screens/quick_share.dart';
import 'package:slickbill/feature_send/utils/send_invoices_class.dart';

class SendNfcInvoice extends HookWidget {
  const SendNfcInvoice({super.key});

  @override
  Widget build(BuildContext context) {
    final NavigationController navigationController = Get.find();
    final UserController userController = Get.find();
    final digitalInvoiceController = Get.find<DigitalInvoiceController>();

    SendInvoicesClass sendInvoicesClass = SendInvoicesClass();

    final tabController = useTabController(initialLength: 3);
    final currentTab = useState(0);

    var receiverUserId = useState<String>('');
    var receiverUserName = useState<String>('');
    var receiverUserAmount = useState<double>(0.0);
    var qrData = useState<String>("");

    var publicInvoiceToken = useState<String?>(null);
    var isCreatingPublicInvoice = useState(false);

    var descriptionController = useTextEditingController();
    var dueDateController = useTextEditingController();
    var referenceNumberController = useTextEditingController();

    var category = useState<String>(Constants().categories.last);

    var originalInvoiceNoController = useTextEditingController();
    var qrCodeReadValue = useState<String>('');
    var selectedDirectUser = useState<UsersByUsername?>(null);
    var isSendingDirectInvoice = useState<bool>(false);

    final directReceivers = useState<List<ReceiverUserModel>>([]);

    useEffect(() {
      if (dueDateController.text == '') {
        final today = DateTime.now();
        final sevenDaysFromNow = today.add(const Duration(days: 7));

        dueDateController.text =
            DateFormat('yyyy-MM-dd').format(sevenDaysFromNow);
      }

      return null;
    }, [dueDateController.text]);

    Future createInvoice() async {
      if (receiverUserId.value.isNotEmpty) {
        await sendInvoicesClass.createSendPrivateNFCInvoice(
            originalInvoiceNoController.text,
            descriptionController.text,
            dueDateController.text,
            referenceNumberController.text,
            receiverUserId.value,
            receiverUserAmount.value,
            category.value);
      }

      navigationController.changeIndex(0);
    }

    FutureOr<List<UsersByUsername>> getOptions(query) async {
      final response = await sendInvoicesClass.getUsersByUsername(query);

      print('getOptions response: $response');

      return response != null ? response.toList() : [];
    }

    changeReceiverAmount(double amount) {
      receiverUserAmount.value = amount;
    }

    void startReadNfc() async {
      Get.snackbar('Starting to read!', 'Bring a phone closer');
      bool isAvailable = await NfcManager.instance.isAvailable();

      try {
        if (isAvailable) {
          NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
            try {
              debugPrint('NFC Tag Detected: ${tag.data["ndef"]}');

              if (tag.data["ndef"].containsKey('cachedMessage')) {
                var cachedMessage = tag.data["ndef"]['cachedMessage'];
                var records = cachedMessage['records'];

                for (var record in records) {
                  int typeNameFormat = record['typeNameFormat'];
                  List<int> type = record['type'];
                  List<int> payload = record['payload'];

                  String typeString = String.fromCharCodes(type);

                  if (typeNameFormat == 1 && typeString == 'T') {
                    int languageCodeLength = payload[0];
                    String textContent =
                        utf8.decode(payload.sublist(1 + languageCodeLength));

                    receiverUserId.value = textContent.split('-').first;
                    receiverUserName.value = textContent.split('-').last;

                    Get.snackbar('NFC Received!',
                        'Sending a slickbill to a user! ${receiverUserName.value}');

                    await createInvoice();
                  }
                }
              } else {
                debugPrint('No cached NDEF message found.');
              }
            } catch (e) {
              debugPrint('Error emitting NFC data: $e');
              NfcManager.instance.stopSession();
            }
          });
        }
      } catch (e) {
        debugPrint('Error writing to NFC: $e');
      }
    }

    String? _handleBarcode(BarcodeCapture barcodes) {
      return barcodes.barcodes.firstOrNull?.rawValue;
    }

    Future<void> createSlickillFromQR(result) async {
      try {
        Map<String, dynamic> jsonObject = jsonDecode(result);

        await sendInvoicesClass.createReceivePrivateQRInvoice(
          jsonObject['description'],
          jsonObject['dueDate'],
          jsonObject['referenceNumber'],
          jsonObject['senderPrivateUserId'],
          jsonObject['senderName'],
          jsonObject['amount'],
          jsonObject['category'],
        );

        navigationController.changeIndex(0);

        Get.snackbar('Slickbill Received', 'Received a slickbill from a user!');
      } catch (e) {
        debugPrint('Error parsing QR code: $e');
        Get.snackbar('Error', 'Failed to process the QR code.');
      }
    }

    void scanQR() {
      bool isProcessing = false;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MobileScanner(
            onDetect: (BarcodeCapture barcodes) {
              if (!isProcessing) {
                isProcessing = true;
                final scannedResult = _handleBarcode(barcodes);
                if (scannedResult != null) {
                  qrCodeReadValue.value = scannedResult;

                  Navigator.of(context).pop();

                  Get.snackbar(
                      'QR Code Scanned', 'Processing the slickbill...');

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
      );
    }

    useEffect(() {
      final result = qrCodeReadValue.value;

      if (result.isNotEmpty) {
        createSlickillFromQR(result);
      }

      return null;
    }, [qrCodeReadValue.value]);

    void updateQRData() {
      qrData.value = jsonEncode({
        'description': descriptionController.value.text,
        'dueDate': dueDateController.text,
        'referenceNumber': referenceNumberController.text,
        'senderPrivateUserId': userController.user.value.privateUserId,
        'senderName':
            '${userController.user.value.firstName} ${userController.user.value.lastName}',
        'amount': receiverUserAmount.value,
        'category': category.value,
      });
    }

    useEffect(() {
      descriptionController.addListener(updateQRData);
      dueDateController.addListener(updateQRData);
      referenceNumberController.addListener(updateQRData);

      return null;
    }, []);

    useEffect(() {
      updateQRData();

      return null;
    }, [receiverUserAmount.value, category.value]);

    useEffect(() {
      void listener() {
        currentTab.value = tabController.index;
      }

      tabController.addListener(listener);
      return () => tabController.removeListener(listener);
    }, [tabController]);

    Future<void> createPublicInvoiceForQR() async {
      if (receiverUserAmount.value <= 0) {
        Get.snackbar('Error', 'Please enter an amount greater than 0');
        return;
      }

      isCreatingPublicInvoice.value = true;

      try {
        final publicInvoice =
            await digitalInvoiceController.createPublicInvoice(
          status: 'UNPAID',
          amount: receiverUserAmount.value,
          description: descriptionController.text,
          deadline: DateTime.parse(dueDateController.text),
          referenceNo: referenceNumberController.text,
          category: category.value,
          senderName:
              '${userController.user.value.firstName} ${userController.user.value.lastName}',
          senderIban: userController.user.value.iban,
          senderPrivateUserId: userController.user.value.privateUserId,
        );

        print('Public Invoice Created: $publicInvoice.public');

        if (publicInvoice != null) {
          publicInvoiceToken.value = publicInvoice.publicToken;
          qrData.value =
              'https://app.slickbills.com/bill/${publicInvoice.publicToken}';

          Get.snackbar(
            'Public Invoice Created!',
            'Share this QR code with anyone',
            backgroundColor: Colors.green.withOpacity(0.1),
            colorText: Colors.green,
            icon: Icon(Icons.check_circle, color: Colors.green),
          );
        }
      } catch (e) {
        Get.snackbar('Error', 'Failed to create public invoice: $e');
        isCreatingPublicInvoice.value = false;
      } finally {
        isCreatingPublicInvoice.value = false;
      }
    }

    Future<void> createDirectShareInvoice() async {
      if (directReceivers.value.isEmpty) {
        Get.snackbar('Oops..', 'Add at least one username with amount');
        return;
      }

      isSendingDirectInvoice.value = true;
      try {
        if (directReceivers.value.length == 1) {
          final r = directReceivers.value.first;
          await sendInvoicesClass.createSendPrivateInvoice(
              originalInvoiceNoController.text,
              descriptionController.text,
              dueDateController.text,
              referenceNumberController.text,
              directReceivers.value,
              category.value);
        } else {
          await sendInvoicesClass.createSendGroupInvoice(
            originalInvoiceNoController.text,
            descriptionController.text,
            dueDateController.text,
            referenceNumberController.text,
            directReceivers.value,
            category.value,
          );
        }

        navigationController.changeIndex(0);
      } catch (e) {
        Get.snackbar('Error', 'Failed to send invoice: $e');
      } finally {
        isSendingDirectInvoice.value = false;
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.light,
      appBar: AppBar(
        title: Text(
          'Invoice Exchange',
          style: TextStyle(
            color: Theme.of(context).colorScheme.dark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: tabController,
              labelColor: Theme.of(context).colorScheme.blue,
              unselectedLabelColor: Theme.of(context).colorScheme.darkGray,
              indicatorColor: Theme.of(context).colorScheme.blue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.userGroup, size: 14),
                      SizedBox(width: 6),
                      Text('In-app QR'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.qrcode, size: 14),
                      SizedBox(width: 6),
                      Text('Public QR'),
                    ],
                  ),
                ),
                // ✅ Tab 3: Direct Share - More compact
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.paperPlane, size: 14),
                      SizedBox(width: 6),
                      Text('Username'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          QuickShareScreen(
            qrData: qrData,
            publicInvoiceToken: publicInvoiceToken,
            receiverUserAmount: receiverUserAmount,
            descriptionController: descriptionController,
            dueDateController: dueDateController,
            referenceNumberController: referenceNumberController,
            category: category,
            isCreatingPublicInvoice: isCreatingPublicInvoice,
            createPublicInvoiceForQR: createPublicInvoiceForQR,
            changeReceiverAmount: changeReceiverAmount,
            startReadNfc: () {
              startReadNfc();
            },
            scanQR: () {
              scanQR();
            },
          ),
          _buildPublicShareTab(
            context: context,
            qrData: qrData,
            publicInvoiceToken: publicInvoiceToken,
            receiverUserAmount: receiverUserAmount,
            descriptionController: descriptionController,
            dueDateController: dueDateController,
            referenceNumberController: referenceNumberController,
            category: category,
            isCreatingPublicInvoice: isCreatingPublicInvoice,
            createPublicInvoiceForQR: createPublicInvoiceForQR,
            changeReceiverAmount: changeReceiverAmount,
          ),
          _buildDirectShareTab(
            context: context,
            descriptionController: descriptionController,
            dueDateController: dueDateController,
            referenceNumberController: referenceNumberController,
            category: category,
            getOptions: getOptions,
            createDirectShareInvoice: createDirectShareInvoice,
            isSendingDirectInvoice: isSendingDirectInvoice,
            directReceivers: directReceivers,
          ),
        ],
      ),
    );
  }

  Widget _buildPublicShareTab({
    required BuildContext context,
    required ValueNotifier<String> qrData,
    required ValueNotifier<String?> publicInvoiceToken,
    required ValueNotifier<double> receiverUserAmount,
    required TextEditingController descriptionController,
    required TextEditingController dueDateController,
    required TextEditingController referenceNumberController,
    required ValueNotifier<String> category,
    required ValueNotifier<bool> isCreatingPublicInvoice,
    required Future<void> Function() createPublicInvoiceForQR,
    required Function(double) changeReceiverAmount,
  }) {
    return Column(
      children: [
        // Info Banner
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.lightGray.withOpacity(0.15),
                Theme.of(context).colorScheme.light.withOpacity(0.1),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.public,
                  color: Theme.of(context).colorScheme.blue,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Public Invoice',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.dark,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Anyone can scan to view (opens in app or web)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.darkGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Sticky QR Code (if created)
        if (publicInvoiceToken.value != null)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.blue.withOpacity(0.05),
                  Theme.of(context).colorScheme.turqouise.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.only(
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
                  // Badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.blue,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Public QR Generated',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // QR Code with modern design
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            Theme.of(context).colorScheme.blue.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .blue
                              .withOpacity(0.1),
                          blurRadius: 15,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: qrData.value,
                          version: QrVersions.auto,
                          size: 180,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: Theme.of(context).colorScheme.blue,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: Theme.of(context).colorScheme.dark,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Scan to view invoice',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.darkGray,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final linkToCopy =
                                'https://app.slickbills.com/bill/${publicInvoiceToken.value}';
                            Clipboard.setData(ClipboardData(text: linkToCopy));
                            Get.snackbar(
                              'Copied!',
                              'Link copied to clipboard',
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .green
                                  .withOpacity(0.1),
                              colorText: Theme.of(context).colorScheme.green,
                              icon: Icon(Icons.check_circle,
                                  color: Theme.of(context).colorScheme.green),
                              snackPosition: SnackPosition.BOTTOM,
                              margin: EdgeInsets.all(16),
                              borderRadius: 12,
                            );
                          },
                          icon: Icon(Icons.copy, size: 18),
                          label: Text('Copy Link'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.blue,
                              width: 1.5,
                            ),
                            foregroundColor: Theme.of(context).colorScheme.blue,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Share functionality
                            Get.snackbar('Share', 'Share feature coming soon!');
                          },
                          icon: Icon(Icons.share, size: 18),
                          label: Text('Share'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.blue,
                              width: 1.5,
                            ),
                            foregroundColor: Theme.of(context).colorScheme.blue,
                            padding: EdgeInsets.symmetric(vertical: 14),
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

                  // Generate Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor:
                            Theme.of(context).colorScheme.blue.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isCreatingPublicInvoice.value
                          ? null
                          : createPublicInvoiceForQR,
                      child: isCreatingPublicInvoice.value
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Generating...'),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(FontAwesomeIcons.qrcode, size: 20),
                                SizedBox(width: 12),
                                Text(
                                  publicInvoiceToken.value != null
                                      ? 'Regenerate Public QR'
                                      : 'Generate Public QR',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Help Text
                  if (publicInvoiceToken.value == null)
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .blue
                            .withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .blue
                              .withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Theme.of(context).colorScheme.blue,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This creates a trackable invoice that can be viewed by anyone with the link',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.darkGray,
                              ),
                            ),
                          ),
                        ],
                      ),
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

Widget _buildDirectShareTab({
  required BuildContext context,
  required FutureOr<List<UsersByUsername>> Function(String) getOptions,
  required ValueNotifier<List<ReceiverUserModel>> directReceivers,
  required Future<void> Function() createDirectShareInvoice,
  required ValueNotifier<bool> isSendingDirectInvoice,
  required TextEditingController descriptionController,
  required TextEditingController dueDateController,
  required TextEditingController referenceNumberController,
  required ValueNotifier<String> category,
}) {
  final canSend = directReceivers.value.isNotEmpty &&
      directReceivers.value.every((e) => e.amount > 0) &&
      !isSendingDirectInvoice.value;

  void changeReceiverAmount(int id, double amount) {
    final updated = [...directReceivers.value];
    final i = updated.indexWhere((e) => e.id == id);
    if (i == -1) return;
    updated[i].amount = amount;
    directReceivers.value = updated;
  }

  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send directly by username',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          TypeAheadField<UsersByUsername>(
            suggestionsCallback: (pattern) => getOptions(pattern),
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.dark,
                ),
                decoration: InputDecoration(
                  hintText: '@username',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            },
            itemBuilder: (context, suggestion) {
              return ListTile(
                title: Text('@${suggestion.users.username}'),
                subtitle:
                    Text('${suggestion.firstName} ${suggestion.lastName}'),
              );
            },
            onSelected: (suggestion) {
              // debug check
              debugPrint(
                  'selected user: ${suggestion.id} / ${suggestion.users.username}');

              if (suggestion.id == null) {
                Get.snackbar('Oops..', 'Invalid user id');
                return;
              }

              final exists =
                  directReceivers.value.any((e) => e.id == suggestion.id);
              if (exists) {
                Get.snackbar(
                    'Info', '@${suggestion.users.username} already added');
                return;
              }

              // IMPORTANT: immutable update (triggers rebuild)
              directReceivers.value = [
                ...directReceivers.value,
                ReceiverUserModel(
                  id: suggestion.id,
                  userId: suggestion.users.id,
                  firstName: suggestion.firstName,
                  lastName: suggestion.lastName,
                  username: suggestion.users.username,
                  amount: 0.0, // mandatory
                ),
              ];
            },
          ),
          const SizedBox(height: 12),
          if (directReceivers.value.isNotEmpty)
            Column(
              children: directReceivers.value.map((receiverUser) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Theme.of(context).colorScheme.blue),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${receiverUser.firstName} ${receiverUser.lastName}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.dark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              directReceivers.value = directReceivers.value
                                  .where((e) => e.id != receiverUser.id)
                                  .toList();
                            },
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.red),
                          ),
                        ],
                      ),
                      Text('@${receiverUser.username}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.darkGray,
                            fontSize: 12,
                          )),
                      const SizedBox(height: 10),
                      InputFieldAmount(
                        receiverUser: receiverUser,
                        changeReceiverAmount: (int id, double amount) {
                          final updated = [...directReceivers.value];
                          final i = updated.indexWhere((e) => e.id == id);
                          if (i == -1) return;
                          updated[i].amount = amount;
                          directReceivers.value = updated; // IMPORTANT
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          InputField(
            icon: Icons.description,
            label: 'Description',
            controller: descriptionController,
          ),
          const SizedBox(height: 12),
          InputField(
            icon: Icons.calendar_today,
            label: 'Due Date',
            controller: dueDateController,
            type: TextInputType.datetime,
          ),
          const SizedBox(height: 12),
          InputField(
            icon: Icons.numbers,
            label: 'Reference Number',
            controller: referenceNumberController,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: canSend ? createDirectShareInvoice : null,
              child: isSendingDirectInvoice.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Invoice'),
            ),
          ),
        ],
      ),
    ),
  );
}
