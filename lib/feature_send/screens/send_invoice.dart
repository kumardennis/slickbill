import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/constants.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_self_create/utils/create_invoices_class.dart';
import 'package:slickbill/feature_self_create/utils/files_class.dart';
import 'package:slickbill/feature_send/utils/send_invoices_class.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

import '../../feature_navigation/getx_controllers/navigation_controller.dart';
import '../../feature_self_create/models/extracted_invoice_data_model.dart';
import '../../feature_self_create/widgets/input_field.dart';
import '../../feature_self_create/widgets/input_field_amount.dart';
import '../models/receiver_user_model.dart';
import '../models/users_by_username_model.dart';

class SendInvoice extends HookWidget {
  const SendInvoice({super.key});

  @override
  Widget build(BuildContext context) {
    final NavigationController navigationController = Get.find();
    final userController = Get.find<UserController>();
    final digitalInvoiceController = Get.find<DigitalInvoiceController>();

    var receiverUsers = useState<List<ReceiverUserModel>>([]);

    var descriptionController = useTextEditingController();
    var dueDateController = useTextEditingController();
    var referenceNumberController = useTextEditingController();

    var category = useState<String>(Constants().categories.last);

    var originalInvoiceNoController = useTextEditingController();

    var receiverUserId = useState<int?>(null);

    final isLoading = useState<bool>(false);

    useEffect(() {
      if (dueDateController.text == '') {
        final today = DateTime.now();
        final sevenDaysFromNow = today.add(const Duration(days: 7));

        dueDateController.text =
            DateFormat('yyyy-MM-dd').format(sevenDaysFromNow);
      }
    }, [dueDateController.text]);

    SendInvoicesClass sendInvoicesClass = SendInvoicesClass();

    Future<void> showAmountDialog(
        BuildContext context, Function(double) onAmountEntered) async {
      final amountController = TextEditingController();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.light,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Enter Amount',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.dark,
                  fontWeight: FontWeight.bold,
                ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.dark,
                      fontWeight: FontWeight.w600,
                    ),
                decoration: InputDecoration(
                  labelText: 'Amount (EUR)',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.darkGray,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, top: 14),
                    child: Text(
                      '€',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.blue,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.gray,
                  ),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.gray.withOpacity(0.3),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.gray,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.blue,
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.blue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This amount will be shown to everyone who receives the link',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.dark,
                              fontSize: 12,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.darkGray,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.pop(context);
                  onAmountEntered(amount);
                } else {
                  Get.snackbar(
                    'Error',
                    'Please enter a valid amount',
                    backgroundColor: Colors.red.withOpacity(0.1),
                    colorText: Colors.red,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.blue,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: Text(
                'Continue',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.light,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Future createInvoice() async {
      print(receiverUsers.value.first.amount);
      if (receiverUsers.value.length == 1) {
        await sendInvoicesClass.createSendPrivateInvoice(
            originalInvoiceNoController.text,
            descriptionController.text,
            dueDateController.text,
            referenceNumberController.text,
            receiverUsers.value,
            category.value);
      }

      if (receiverUsers.value.length > 1) {
        await sendInvoicesClass.createSendGroupInvoice(
            originalInvoiceNoController.text,
            descriptionController.text,
            dueDateController.text,
            referenceNumberController.text,
            receiverUsers.value,
            category.value);
      }

      navigationController.changeIndex(0);
    }

    Future createShareableInvoiceLink() async {
      await showAmountDialog(context, (double amount) async {
        final publicInvoice =
            await digitalInvoiceController.createPublicInvoice(
          status: 'UNPAID',
          amount: amount, // Use the amount from dialog
          description: descriptionController.text,
          deadline: DateTime.parse(dueDateController.text),
          referenceNo: referenceNumberController.text,
          category: category.value,
          senderName:
              '${userController.user.value.firstName} ${userController.user.value.lastName}',
          senderIban: userController.user.value.iban,
          senderPrivateUserId: userController.user.value.privateUserId,
        );

        if (publicInvoice != null) {
          final shareableUrl =
              'https://slickbills.com/#/bill/${publicInvoice.publicToken}';

          // Copy to clipboard
          await Clipboard.setData(ClipboardData(text: shareableUrl));

          Get.snackbar(
            'Shareable Link Created!',
            'Link copied to clipboard',
            messageText: Text(
              shareableUrl,
              style: TextStyle(fontSize: 12),
            ),
            duration: Duration(seconds: 5),
          );
        }
        navigationController.changeIndex(0);
      });
    }

    FutureOr<List<UsersByUsername>> getOptions(query) async {
      final response = await sendInvoicesClass.getUsersByUsername(query);

      return response != null ? response.toList() : [];
    }

    changeReceiverAmount(int id, double amount) {
      print('ID: $id, AMOUNT: $amount');
      receiverUsers.value.firstWhere((receiver) => receiver.id == id).amount =
          amount;
    }

    return (Scaffold(
      appBar: CustomAppbar(title: 'hd_SendASlickbill'.tr, appbarIcon: null),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TypeAheadField<UsersByUsername>(
              builder: (context, controller, focusNode) {
                return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: false,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.dark),
                    decoration: InputDecoration(
                        counterStyle: Theme.of(context).textTheme.bodyMedium,
                        labelText: 'lbl_SearchUsers'.tr,
                        fillColor: Theme.of(context).colorScheme.gray));
              },
              suggestionsCallback: (pattern) => getOptions(pattern),
              itemBuilder: (context, UsersByUsername suggestion) {
                return ListTile(
                    leading: const FaIcon(FontAwesomeIcons.user),
                    title: Text(
                      suggestion.users.username,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.dark),
                    ),
                    subtitle: Text(
                      '${suggestion.firstName} ${suggestion.lastName}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.darkGray),
                    ));
              },
              onSelected: (suggestion) {
                receiverUserId.value = suggestion.id;
                receiverUsers.value.add(ReceiverUserModel(
                    userId: suggestion.users.id,
                    amount: 0.0,
                    firstName: suggestion.firstName,
                    lastName: suggestion.lastName,
                    id: suggestion.id));
              },
            ),
            Wrap(
              children: receiverUsers.value
                  .map((receiverUser) => Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Container(
                          width: MediaQuery.of(context).size.width / 3,
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.darkGray,
                              borderRadius: BorderRadius.circular(10.0)),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(children: [
                              GestureDetector(
                                  onTap: () {
                                    receiverUsers.value = receiverUsers.value
                                        .where((element) =>
                                            element.id != receiverUser.id)
                                        .toList();
                                  },
                                  child: Text(receiverUser.firstName)),
                              InputFieldAmount(
                                  receiverUser: receiverUser,
                                  changeReceiverAmount: changeReceiverAmount),
                            ]),
                          ),
                        ),
                      ))
                  .toList(),
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
                width: MediaQuery.of(context).size.width - 100,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.blue),
                    onPressed: createShareableInvoiceLink,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Share Link',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: Theme.of(context).colorScheme.light),
                          ),
                          const SizedBox(width: 10),
                          FaIcon(
                            FontAwesomeIcons.link,
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
                width: MediaQuery.of(context).size.width - 100,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.blue),
                    onPressed: createInvoice,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'btn_Send'.tr,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: Theme.of(context).colorScheme.light),
                          ),
                          const SizedBox(width: 10),
                          FaIcon(
                            FontAwesomeIcons.rocket,
                            color: Theme.of(context).colorScheme.light,
                          )
                        ],
                      ),
                    )),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ));
  }
}
