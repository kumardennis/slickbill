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
                    backgroundColor: Theme.of(context).colorScheme.red,
                    colorText: Colors.white,
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
              'https://app.slickbills.com/bill/${publicInvoice.publicToken}';

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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.light,
      // appBar: CustomAppbar(title: 'Send Slickbill'.tr, appbarIcon: null),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Card for User Search
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send to',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.dark,
                                ),
                      ),
                      const SizedBox(height: 12),
                      TypeAheadField<UsersByUsername>(
                        builder: (context, controller, focusNode) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            autofocus: false,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.dark,
                                  fontWeight: FontWeight.w500,
                                ),
                            decoration: InputDecoration(
                              hintText: 'Search users by name...',
                              hintStyle: TextStyle(
                                color: Theme.of(context).colorScheme.darkGray,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.blue,
                              ),
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .gray
                                  .withOpacity(0.3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.blue,
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        },
                        suggestionsCallback: (pattern) => getOptions(pattern),
                        itemBuilder: (context, UsersByUsername suggestion) {
                          return Container(
                            color: Colors.white,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .blue
                                    .withOpacity(0.1),
                                child: FaIcon(
                                  FontAwesomeIcons.user,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.blue,
                                ),
                              ),
                              title: Text(
                                suggestion.users.username,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.dark,
                                    ),
                              ),
                              subtitle: Text(
                                '${suggestion.firstName} ${suggestion.lastName}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .darkGray,
                                    ),
                              ),
                            ),
                          );
                        },
                        onSelected: (suggestion) {
                          receiverUserId.value = suggestion.id;
                          receiverUsers.value.add(ReceiverUserModel(
                            userId: suggestion.users.id,
                            amount: 0.0,
                            username: suggestion.users.username,
                            firstName: suggestion.firstName,
                            lastName: suggestion.lastName,
                            id: suggestion.id,
                          ));
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Selected Users Chips
              if (receiverUsers.value.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: receiverUsers.value.map((receiverUser) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors
                            .white, // ✅ White background instead of transparent blue
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.blue,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: Theme.of(context).colorScheme.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${receiverUser.firstName} ${receiverUser.lastName}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .dark, // ✅ Dark text
                                    ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  receiverUsers.value = receiverUsers.value
                                      .where((element) =>
                                          element.id != receiverUser.id)
                                      .toList();
                                },
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 120,
                            child: InputFieldAmount(
                              receiverUser: receiverUser,
                              changeReceiverAmount: changeReceiverAmount,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 24),

              // Bill Details Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill Details',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.dark,
                                ),
                      ),
                      const SizedBox(height: 16),
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Category Selection
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.dark,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: Constants().categories.map((item) {
                          final isSelected = category.value == item;
                          return GestureDetector(
                            onTap: () => category.value = item,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.blue
                                    : Theme.of(context)
                                        .colorScheme
                                        .gray
                                        .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.blue
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                item,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(context).colorScheme.dark,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              // Share Link Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: receiverUsers.value.isEmpty ? null : createInvoice,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.paperPlane,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Send To Users',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
