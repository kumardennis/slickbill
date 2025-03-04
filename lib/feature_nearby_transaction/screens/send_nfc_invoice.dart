import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/constants.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:slickbill/feature_nearby_transaction/screens/make_nfc_available.dart';
import 'package:flutter_pro_barcode_scanner/flutter_pro_barcode_scanner.dart';
import 'package:slickbill/feature_nearby_transaction/widgets/big_input_amount.dart';
import 'package:slickbill/feature_self_create/widgets/input_field.dart';
import 'package:slickbill/feature_send/models/users_by_username_model.dart';
import 'package:slickbill/feature_send/utils/send_invoices_class.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

class SendNfcInvoice extends HookWidget {
  const SendNfcInvoice({super.key});

  @override
  Widget build(BuildContext context) {
    final NavigationController navigationController = Get.find();
    final UserController userController = Get.find();

    SendInvoicesClass sendInvoicesClass = SendInvoicesClass();

    var receiverUserId = useState<String>('');
    var receiverUserName = useState<String>('');
    var receiverUserAmount = useState<double>(0.0);
    var qrData = useState<String>("");

    var descriptionController = useTextEditingController();
    var dueDateController = useTextEditingController();
    var referenceNumberController = useTextEditingController();

    var category = useState<String>(Constants().categories.last);

    var originalInvoiceNoController = useTextEditingController();

    useEffect(() {
      if (dueDateController.text == '') {
        final today = DateTime.now();
        final sevenDaysFromNow = today.add(const Duration(days: 7));

        dueDateController.text =
            DateFormat('yyyy-MM-dd').format(sevenDaysFromNow);
      }
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

    FutureOr<Iterable<UsersByUsername>> getOptions(query) async {
      final response = await sendInvoicesClass.getUsersByUsername(query);

      return response != null ? response.toList() : [];
    }

    changeReceiverAmount(double amount) {
      receiverUserAmount.value = amount;
    }

    void startReadNfc() async {
      Get.snackbar('Starting to read!', 'Bring a phone closer');
      // # check if NFC is available on the device or not.
      bool isAvailable = await NfcManager.instance.isAvailable();

      try {
        // # If NFC is available, start a session to listen for NFC tags.
        if (isAvailable) {
          NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
            try {
              debugPrint('NFC Tag Detected: ${tag.data["ndef"]}');

              // Check if the tag has a cached NDEF message
              if (tag.data["ndef"].containsKey('cachedMessage')) {
                var cachedMessage = tag.data["ndef"]['cachedMessage'];
                var records = cachedMessage['records'];

                for (var record in records) {
                  int typeNameFormat = record['typeNameFormat'];
                  List<int> type = record['type'];
                  List<int> payload = record['payload'];

                  String typeString = String.fromCharCodes(type);

                  // Additional parsing for text payloads
                  if (typeNameFormat == 1 && typeString == 'T') {
                    int languageCodeLength = payload[0];
                    String languageCode =
                        utf8.decode(payload.sublist(1, 1 + languageCodeLength));
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

    // useEffect(() {
    //   return () => NfcManager.instance.stopSession();
    // }, []);

    Future<void> scanQR() async {
      String scannedCode = await Navigator.push(context,
          MaterialPageRoute(builder: (context) => const ScannerScreen()));

      debugPrint(scannedCode);

      Map<String, dynamic> jsonObject = jsonDecode(scannedCode);

      print(jsonObject);

      await sendInvoicesClass.createReceivePrivateQRInvoice(
          jsonObject['description'],
          jsonObject['dueDate'],
          jsonObject['referenceNumber'],
          jsonObject['senderPrivateUserId'],
          jsonObject['amount'],
          jsonObject['category']);

      navigationController.changeIndex(0);

      Get.snackbar('Slickbill Received', 'Received a slickbill from a user!');
    }

    void updateQRData() {
      qrData.value = jsonEncode({
        'description': descriptionController.value.text,
        'dueDate': dueDateController.text,
        'referenceNumber': referenceNumberController.text,
        'senderPrivateUserId': userController.user.value.privateUserId,
        'amount': receiverUserAmount.value,
        'category': category.value,
      });
    }

    useEffect(() {
      descriptionController.addListener(updateQRData);
      dueDateController.addListener(updateQRData);
      referenceNumberController.addListener(updateQRData);
    }, []);

    useEffect(() {
      updateQRData();
    }, [receiverUserAmount.value, category.value]);

    return (Scaffold(
      appBar: CustomAppbar(title: 'hd_NfcTransaction'.tr, appbarIcon: null),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BigInputAmount(changeReceiverAmount: changeReceiverAmount),
            QrImageView(
              data: qrData.value,
              version: QrVersions.auto,
              size: 320,
              gapless: false,
            ),
            InputField(
              controller: descriptionController,
              label: 'lbl_Description'.tr,
            ),
            InputField(
              controller: dueDateController,
              label: 'lbl_DueDate'.tr,
            ),
            InputField(
              controller: referenceNumberController,
              label: 'lbl_ReferenceNumber'.tr,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Wrap(
                spacing: 5.0,
                runSpacing: 5.0,
                children: Constants().categories.map(
                  (item) {
                    return ChoiceChip(
                      backgroundColor: Theme.of(context).colorScheme.gray,
                      selectedColor: Theme.of(context).colorScheme.blue,
                      label: Text(
                        item,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      selected: category.value == item,
                      onSelected: (bool selected) {
                        category.value = item;
                      },
                    );
                  },
                ).toList(),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 50,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.blue),
                    onPressed: startReadNfc,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'btn_StartNfcSession'.tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: Theme.of(context).colorScheme.light),
                          ),
                          const SizedBox(width: 10),
                          FaIcon(
                            FontAwesomeIcons.nfcSymbol,
                            color: Theme.of(context).colorScheme.light,
                          )
                        ],
                      ),
                    )),
              ),
            ),
            // const SizedBox(height: 40),
            // Center(
            //   child: SizedBox(
            //     width: MediaQuery.of(context).size.width - 50,
            //     child: ElevatedButton(
            //         style: ElevatedButton.styleFrom(
            //             backgroundColor: Theme.of(context).colorScheme.blue),
            //         onPressed: () {
            //           Navigator.push(
            //               context,
            //               MaterialPageRoute(
            //                   builder: (context) => const MakeNfcAvailable()));
            //         },
            //         child: Padding(
            //           padding: const EdgeInsets.all(15.0),
            //           child: Row(
            //             mainAxisAlignment: MainAxisAlignment.center,
            //             children: [
            //               Text(
            //                 'btn_SearchNearbyDevices'.tr,
            //                 style: Theme.of(context)
            //                     .textTheme
            //                     .bodyLarge
            //                     ?.copyWith(
            //                         color: Theme.of(context).colorScheme.light),
            //               ),
            //               const SizedBox(width: 10),
            //               FaIcon(
            //                 FontAwesomeIcons.bluetooth,
            //                 color: Theme.of(context).colorScheme.light,
            //               )
            //             ],
            //           ),
            //         )),
            //   ),
            // ),
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 50,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.blue),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MakeNfcAvailable()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'btn_ReceiveSlickbillNfc'.tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: Theme.of(context).colorScheme.light),
                          ),
                          const SizedBox(width: 10),
                          FaIcon(
                            FontAwesomeIcons.download,
                            color: Theme.of(context).colorScheme.light,
                          )
                        ],
                      ),
                    )),
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 50,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.blue),
                    onPressed: () {
                      scanQR();
                      // Navigator.push(
                      //     context,
                      //     MaterialPageRoute(
                      //         builder: (context) => const ReadQrInvoice()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'btn_ReceiveSlickbillNfc'.tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: Theme.of(context).colorScheme.light),
                          ),
                          const SizedBox(width: 10),
                          FaIcon(
                            FontAwesomeIcons.qrcode,
                            color: Theme.of(context).colorScheme.light,
                          )
                        ],
                      ),
                    )),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
