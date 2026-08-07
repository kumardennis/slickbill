import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_send/models/users_by_username_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../models/receiver_user_model.dart';

class SendInvoicesClass {
  final UserController userController = Get.find<UserController>();
  CurrentBankController currentBankController = Get.find();

  Future<void> createSendPrivateInvoice(originalInvoiceNo, description, dueDate,
      referenceNo, List<ReceiverUserModel> receiverUsers, category) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/create-private-user-invoice', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "privateUserId": userController.user.value.privateUserId,
        "senderName":
            '${userController.user.value.firstName} ${userController.user.value.lastName}',

        "senderIban": currentBankController.current.value.iban,

        "receiverUserId": receiverUsers.first.userId,
        "receiverPrivateUserId": receiverUsers.first.id,
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

  Future<void> createSendPrivateNFCInvoice(
      originalInvoiceNo,
      description,
      dueDate,
      referenceNo,
      receiverUserId,
      receiverUserAmount,
      category) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/create-private-user-invoice', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "privateUserId": userController.user.value.privateUserId,
        "senderName":
            '${userController.user.value.firstName} ${userController.user.value.lastName?[0].toUpperCase()}',

        "senderIban": currentBankController.current.value.iban.isNotEmpty
            ? currentBankController.current.value.iban
            : userController.user.value.iban,
        "receiverUserId": receiverUserId,
        "receiverIsPrivate": true,
        // "originalInvoiceNo": originalInvoiceNo,
        "amount": receiverUserAmount,
        "description": description,
        "dueDate": dueDate,
        "referenceNo": referenceNo,
        "category": category
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Get.snackbar('Success', 'inf_AddedToSlickBill'.tr);
      } else {
        debugPrint(data['error'].toString());
        Get.snackbar('Oops..', data['error'].toString());
        return null;
      }
    } catch (err) {
      print(err);
      return null;
    }
  }

  Future<String?> createReceivePrivateQRInvoice(
      description,
      dueDate,
      referenceNo,
      senderPrivateUserId,
      senderName,
      senderIban,
      receiverUserAmount,
      category) async {
    try {
      var normalizedSenderIban = (senderIban ?? '').toString().trim();

      if (normalizedSenderIban.isEmpty) {
        final senderPrivateUserIdValue = senderPrivateUserId is int
            ? senderPrivateUserId
            : int.tryParse(senderPrivateUserId.toString());

        if (senderPrivateUserIdValue != null) {
          try {
            final senderRow = await Supabase.instance.client
                .from('private_users')
                .select('iban')
                .eq('id', senderPrivateUserIdValue)
                .maybeSingle();

            normalizedSenderIban = (senderRow?['iban'] ?? '').toString().trim();

            if (normalizedSenderIban.isNotEmpty) {
              debugPrint(
                '[QRReceive] senderIban resolved from private_users.id=$senderPrivateUserIdValue',
              );
            }
          } catch (lookupError) {
            debugPrint(
              '[QRReceive] senderIban lookup failed for senderPrivateUserId=$senderPrivateUserIdValue error=$lookupError',
            );
          }
        }
      }

      if (normalizedSenderIban.isEmpty) {
        debugPrint(
          '[QRReceive] senderIban missing. senderPrivateUserId=$senderPrivateUserId senderName=$senderName amount=$receiverUserAmount',
        );
        Get.snackbar(
          'Invalid QR code',
          'Sender IBAN is missing in QR payload. Ask sender to regenerate QR.',
        );
        return null;
      }

      final response = await Supabase.instance.client.functions
          .invoke('invoices/create-private-user-invoice', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "privateUserId": senderPrivateUserId,
        "senderName": senderName,
        "senderIban": normalizedSenderIban,
        "receiverUserId": userController.user.value.id,
        "receiverPrivateUserId": userController.user.value.privateUserId,
        "receiverIsPrivate": true,
        // "originalInvoiceNo": originalInvoiceNo,
        "amount": receiverUserAmount,
        "description": description,
        "dueDate": dueDate,
        "referenceNo": referenceNo,
        "category": category
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        // No local success toast — FCM "X sent you a slickbill" owns that UX.
        return data['data']['digitalInvoiceData']['id'];
      } else {
        debugPrint(data['error'].toString());
        // Let the QR caller show a single error toast.
        throw Exception(data['error']?.toString() ?? 'Failed to create invoice');
      }
    } catch (err) {
      print(err);
      rethrow;
    }
  }

  Future<void> createSendGroupInvoice(originalInvoiceNo, description, dueDate,
      referenceNo, List<ReceiverUserModel> receiverUsers, category) async {
    List<Map<String, dynamic>> receivers = [];

    for (var element in receiverUsers) {
      receivers.add({
        'receiverUserId': element.userId,
        'receiverPrivateUserId': element.id,
        'amount': element.amount
      });
    }

    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/create-private-group-invoice', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "privateUserId": userController.user.value.privateUserId,
        "senderName":
            '${userController.user.value.firstName} ${userController.user.value.lastName?[0].toUpperCase()}',
        "senderIban": currentBankController.current.value.iban,
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
      return null;
    }
  }
}
