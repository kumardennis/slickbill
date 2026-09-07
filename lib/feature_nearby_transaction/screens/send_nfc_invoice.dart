import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:slickbill/constants.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:slickbill/feature_nearby_transaction/widgets/big_input_amount.dart';
import 'package:slickbill/feature_nearby_transaction/widgets/invoice_request_fields.dart';
import 'package:slickbill/services/sb_feedback.dart';
import 'package:slickbill/feature_send/models/receiver_user_model.dart';
import 'package:slickbill/feature_send/models/users_by_username_model.dart';
import 'package:slickbill/feature_send/screens/quick_share.dart';
import 'package:slickbill/feature_send/utils/send_invoices_class.dart';
import 'package:slickbill/feature_send/widgets/compact_receiver_row.dart';
import 'package:slickbill/shared_utils/scanned_qr_router.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:slickbill/shared_widgets/sb_labeled_field.dart';
import 'package:slickbill/shared_widgets/sb_qr_panel.dart';
import 'package:slickbill/shared_widgets/sb_segmented_control.dart';
import 'package:slickbill/shared_widgets/sb_trust_banner.dart';
import 'package:slickbill/theme/sb_colors.dart';

class SendNfcInvoice extends HookWidget {
  const SendNfcInvoice({super.key});

  @override
  Widget build(BuildContext context) {
    final NavigationController navigationController = Get.find();
    final UserController userController = Get.find();
    final CurrentBankController currentBankController = Get.find();
    final digitalInvoiceController = Get.find<DigitalInvoiceController>();

    SendInvoicesClass sendInvoicesClass = SendInvoicesClass();

    final tabController = useTabController(
      initialLength: 3,
      initialIndex: digitalInvoiceController.directShareDraft.value != null
          ? 2
          : navigationController.exchangeTabIndex.value,
    );
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

    useEffect(() {
      final draft = digitalInvoiceController.consumeDirectShareDraft();
      if (draft == null) return null;

      descriptionController.text = draft.description;
      referenceNumberController.text = draft.referenceNo;
      category.value = draft.category;
      directReceivers.value = [draft.receiver];

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (tabController.index != 2) {
          tabController.animateTo(2);
        }
      });

      return null;
    }, const []);

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

                    unawaited(SbFeedback.confirm());
                    await createInvoice();
                  }
                }
              } else {
                debugPrint('No cached NDEF message found.');
              }
            } catch (e) {
              debugPrint('Error emitting NFC data: $e');
              unawaited(SbFeedback.error());
              NfcManager.instance.stopSession();
            }
          });
        }
      } catch (e) {
        debugPrint('Error writing to NFC: $e');
        unawaited(SbFeedback.error());
      }
    }

    String? _handleBarcode(BarcodeCapture barcodes) {
      final rawValue = barcodes.barcodes.firstOrNull?.rawValue;
      if (rawValue == null) return null;
      return rawValue.trim();
    }

    Future<void> createSlickillFromQR(result) async {
      try {
        if (await navigateScannedQrPayload(result.toString())) {
          return;
        }

        Map<String, dynamic> jsonObject = jsonDecode(result);

        await sendInvoicesClass.createReceivePrivateQRInvoice(
          jsonObject['description'],
          jsonObject['dueDate'],
          jsonObject['referenceNumber'],
          jsonObject['senderPrivateUserId'],
          jsonObject['senderName'],
          jsonObject['senderIban'],
          jsonObject['amount'],
          jsonObject['category'],
          jsonObject['senderIsBusiness'] == true,
        );

        navigationController.changeIndex(0);
        unawaited(SbFeedback.received());
        // FCM NEW_SLICKBILL ("X sent you a slickbill") is the user-facing toast.
      } catch (e) {
        debugPrint('Error parsing QR code: $e');
        unawaited(SbFeedback.error());
        Get.snackbar(
          'Error',
          e.toString().replaceFirst('Exception: ', ''),
        );
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
                  unawaited(SbFeedback.confirm());

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

    String resolveSenderIban() {
      final currentBankIban = currentBankController.current.value.iban.trim();
      if (currentBankIban.isNotEmpty) return currentBankIban;

      final userPrimaryIban = (userController.user.value.iban ?? '').trim();
      if (userPrimaryIban.isNotEmpty) return userPrimaryIban;

      final userIbans = userController.user.value.ibans;
      if (userIbans != null && userIbans.isNotEmpty) {
        for (final bank in userIbans) {
          if (bank.isPrimary && bank.iban.trim().isNotEmpty) {
            return bank.iban.trim();
          }
        }

        for (final bank in userIbans) {
          if (bank.iban.trim().isNotEmpty) {
            return bank.iban.trim();
          }
        }
      }

      return '';
    }

    void updateQRData() {
      final senderIban = resolveSenderIban();

      qrData.value = jsonEncode({
        'qrVersion': 2,
        'description': descriptionController.value.text,
        'dueDate': dueDateController.text,
        'referenceNumber': referenceNumberController.text,
        'senderPrivateUserId': userController.user.value.privateUserId,
        'senderName': userController.user.value.requestDisplayName,
        'senderIsBusiness': userController.user.value.isBusiness,
        'senderIban': senderIban,
        'amount': receiverUserAmount.value,
        'category': category.value,
      });

      if (senderIban.isEmpty) {
        debugPrint(
          '[QRGenerate] senderIban is empty. currentBank=${currentBankController.current.value.iban} user.iban=${userController.user.value.iban} user.ibans.count=${userController.user.value.ibans?.length ?? 0}',
        );
      }
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
      final workers = <Worker>[
        ever(currentBankController.current, (_) {
          updateQRData();
        }),
        ever(userController.user, (_) {
          updateQRData();
        }),
      ];

      return () {
        for (final worker in workers) {
          worker.dispose();
        }
      };
    }, const []);

    useEffect(() {
      void listener() {
        currentTab.value = tabController.index;
        navigationController.exchangeTabIndex.value = tabController.index;
      }

      tabController.addListener(listener);
      return () => tabController.removeListener(listener);
    }, [tabController]);

    useEffect(() {
      final worker = ever<int>(navigationController.exchangeTabIndex, (index) {
        if (tabController.index != index) {
          tabController.animateTo(index);
        }
      });
      return worker.dispose;
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
          senderName: userController.user.value.requestDisplayName,
          senderIsBusiness: userController.user.value.isBusiness,
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
      backgroundColor: Colors.transparent,
      appBar: const CustomAppbar(
        title: 'hd_Exchange',
        appbarIcon: null,
        showSettings: true,
        showBrand: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SbSegmentedControl(
              index: currentTab.value,
              onChanged: (i) => tabController.animateTo(i),
              segments: const [
                SbSegment(label: 'In-app QR', icon: Icons.qr_code_rounded),
                SbSegment(label: 'Public QR', icon: Icons.qr_code_2_rounded),
                SbSegment(label: 'Username', icon: Icons.alternate_email),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                QuickShareScreen(
                  qrData: qrData,
                  descriptionController: descriptionController,
                  dueDateController: dueDateController,
                  referenceNumberController: referenceNumberController,
                  category: category,
                  changeReceiverAmount: changeReceiverAmount,
                  scanQR: () {
                    scanQR();
                  },
                ),
                _buildPublicShareTab(
                  context: context,
                  qrData: qrData,
                  publicInvoiceToken: publicInvoiceToken,
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
          ),
        ],
      ),
    );
  }

  Widget _buildPublicShareTab({
    required BuildContext context,
    required ValueNotifier<String> qrData,
    required ValueNotifier<String?> publicInvoiceToken,
    required TextEditingController descriptionController,
    required TextEditingController dueDateController,
    required TextEditingController referenceNumberController,
    required ValueNotifier<String> category,
    required ValueNotifier<bool> isCreatingPublicInvoice,
    required Future<void> Function() createPublicInvoiceForQR,
    required Function(double) changeReceiverAmount,
  }) {
    final hasQr = publicInvoiceToken.value != null;
    final publicLink = hasQr
        ? 'https://app.slickbills.com/bill/${publicInvoiceToken.value}'
        : '';
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 80;

    return ColoredBox(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          children: [
            if (hasQr && !keyboardOpen) ...[
              SbQrPanel(
                data: qrData.value,
                title: 'Public QR',
                caption:
                    'Anyone can scan this. Opens in SlickBills, or the web if they do not have the app.',
                size: 196,
                footer: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: publicLink));
                      Get.snackbar(
                        'Copied',
                        'Public link is on the clipboard.',
                        snackPosition: SnackPosition.BOTTOM,
                        margin: const EdgeInsets.all(16),
                      );
                    },
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Copy link'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
                    referenceNumberController: referenceNumberController,
                    category: category.value,
                    onCategoryChanged: (value) => category.value = value,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isCreatingPublicInvoice.value
                    ? null
                    : createPublicInvoiceForQR,
                style: ElevatedButton.styleFrom(
                  backgroundColor: SbColors.deepNavy,
                  disabledBackgroundColor: SbColors.surfaceHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SbRadii.md),
                  ),
                  elevation: 0,
                ),
                child: isCreatingPublicInvoice.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        hasQr ? 'Update public QR' : 'Generate public QR',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SbTrustBanner(
              variant: SbTrustBannerVariant.custody,
              title: hasQr ? 'This request is public' : 'A QR anyone can open',
              subtitle: hasQr
                  ? 'Share the code or the link. They do not need a SlickBills account to see it.'
                  : 'Fill the request, then generate. The QR and link stay the same until you update them.',
            ),
          ],
        ),
      ),
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
  final total =
      directReceivers.value.fold<double>(0, (sum, e) => sum + e.amount);

  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SbColors.surfaceLowest,
              borderRadius: BorderRadius.circular(SbRadii.md),
              boxShadow: SbShadows.cardSoft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'lbl_SendDirectly'.tr,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: SbColors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                TypeAheadField<UsersByUsername>(
                  debounceDuration: const Duration(milliseconds: 280),
                  suggestionsCallback: (pattern) => getOptions(pattern),
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                        color: SbColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'lbl_SearchUsers'.tr,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12, right: 4),
                          child: Text(
                            '@',
                            style: TextStyle(
                              color: SbColors.deepNavy,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 28, minHeight: 0),
                      ),
                    );
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: SbColors.surfaceLow,
                        child: Text(
                          '${suggestion.firstName.isNotEmpty ? suggestion.firstName[0] : ''}${suggestion.lastName.isNotEmpty ? suggestion.lastName[0] : ''}'
                              .toUpperCase(),
                          style: const TextStyle(
                            color: SbColors.deepNavy,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text('@${suggestion.users.username}'),
                      subtitle: Text(
                          '${suggestion.firstName} ${suggestion.lastName}'
                              .trim()),
                      trailing: const Text(
                        '+ Add',
                        style: TextStyle(
                          color: SbColors.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                  onSelected: (suggestion) {
                    debugPrint(
                        'selected user: ${suggestion.id} / ${suggestion.users.username}');

                    if (suggestion.id == null) {
                      Get.snackbar('Oops..', 'Invalid user id');
                      return;
                    }

                    final exists =
                        directReceivers.value.any((e) => e.id == suggestion.id);
                    if (exists) {
                      Get.snackbar('Info',
                          '@${suggestion.users.username} already added');
                      return;
                    }

                    directReceivers.value = [
                      ...directReceivers.value,
                      ReceiverUserModel(
                        id: suggestion.id,
                        userId: suggestion.users.id,
                        firstName: suggestion.firstName,
                        lastName: suggestion.lastName,
                        username: suggestion.users.username,
                        amount: 0.0,
                      ),
                    ];
                  },
                ),
                if (directReceivers.value.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (var i = 0; i < directReceivers.value.length; i++)
                    Builder(
                      builder: (context) {
                        final receiver = directReceivers.value[i];
                        return CompactReceiverRow(
                          receiverUser: receiver,
                          showDivider: false,
                          onAmountChanged: (int id, double amount) {
                            final updated = [...directReceivers.value];
                            final idx = updated.indexWhere((e) => e.id == id);
                            if (idx == -1) return;
                            updated[idx].amount = amount;
                            directReceivers.value = updated;
                          },
                          onRemove: () {
                            directReceivers.value = directReceivers.value
                                .where((e) => e.id != receiver.id)
                                .toList();
                          },
                        );
                      },
                    ),
                ],
                const SizedBox(height: 12),
                SbLabeledField(
                  label: 'Description',
                  icon: Icons.description_outlined,
                  controller: descriptionController,
                ),
                const SizedBox(height: 8),
                SbLabeledField(
                  label: 'Due Date',
                  icon: Icons.calendar_today_rounded,
                  controller: dueDateController,
                  readOnly: true,
                  onTap: () =>
                      SbLabeledField.pickDate(context, dueDateController),
                ),
                const SizedBox(height: 8),
                SbLabeledField(
                  label: 'Reference Number',
                  icon: Icons.tag_rounded,
                  controller: referenceNumberController,
                  hint: 'Optional invoice or ref #',
                  boldValue: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSend ? createDirectShareInvoice : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: SbColors.deepNavy,
                disabledBackgroundColor: SbColors.surfaceHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SbRadii.md),
                ),
                elevation: 0,
              ),
              child: isSendingDirectInvoice.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'btn_SendTotal'.trParams({
                            'amount': total.toStringAsFixed(2),
                          }),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
