import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_send/models/users_by_username_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../models/receiver_user_model.dart';

class SendInvoicesClass {
  final UserController userController = Get.find();

  Future<void> createSendPrivateInvoice(originalInvoiceNo, description, dueDate,
      referenceNo, List<ReceiverUserModel> receiverUsers, category) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/create-private-user-invoice', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "privateUserId": userController.user.value.privateUserId,
        "senderName":
            '${userController.user.value.firstName} ${userController.user.value.lastName?[0].toUpperCase()}',

        "receiverUserId": receiverUsers.first.id,
        "receiverIsPrivate": true,
        // "originalInvoiceNo": originalInvoiceNo,
        "amount": receiverUsers.first.amount,
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

  Future<void> createSendGroupInvoice(originalInvoiceNo, description, dueDate,
      referenceNo, List<ReceiverUserModel> receiverUsers, category) async {
    List<Map<String, dynamic>> receivers = [];

    for (var element in receiverUsers) {
      receivers.add({'receiverUserId': element.id, 'amount': element.amount});
    }

    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/create-private-group-invoice', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "privateUserId": userController.user.value.privateUserId,
        "senderName":
            '${userController.user.value.firstName} ${userController.user.value.lastName?[0].toUpperCase()}',
        "receiverUsers": receivers,
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

  Future<List<UsersByUsername>?> getUsersByUsername(String query) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('auth-and-settings/get-users-by-username', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "query": query,
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        List<UsersByUsername> users = (data['data'] as List)
            .map((e) => UsersByUsername.fromJson(e))
            .toList();

        print(users);

        return users;
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return null;
      }
    } catch (err) {
      print(err.toString());
    }
  }
}
