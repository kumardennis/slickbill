import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';

class CreateInvoicesClass {
  final UserController userController = Get.find();

  Future<void> createPrivateSelfInvoice(originalInvoiceNo, senderName, iban,
      description, amount, dueDate, referenceNo, category) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/create-private-user-self-invoice', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "privateUserId": userController.user.value.privateUserId,
        "senderName": senderName,
        "senderIban": iban,
        "receiverIsPrivate": true,
        "originalInvoiceNo": originalInvoiceNo,
        "amount": amount,
        "description": description,
        "dueDate": dueDate,
        "referenceNo": referenceNo,
        "category": category
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Get.snackbar('Success', 'inf_AddedToSlickBill'.tr);
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return null;
      }
    } catch (err) {
      print(err);
      return null;
    }
  }
}
