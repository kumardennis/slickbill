import 'package:get/get.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentClass {
  final UserController userController = Get.find();

  Future<String> getPaymentToken(String bankName) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('payment/get-token', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "bankName": bankName,
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Get.snackbar('Success', 'inf_TokenReceived'.tr);
        return data['data']['token'];
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return '';
      }
    } catch (err) {
      print(err);
    }
    throw Exception('Failed to retrieve payment token');
  }

  Future<bool> createSepaTransfer(
      String bankName, String token, String amount) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('payment/create-sepa-transfer', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "bankName": bankName,
        "token": token,
        "accountIban": userController.user.value.iban,
        "amount": amount,
        "creditorAccount": "EE717700771001735865",
        "creditorName": "Liis-MariMnnik",
        "description": "Testing sepa transfer",
        "reference": "null"
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Get.snackbar('Success', 'inf_PaymentInitiated'.tr);
        return true;
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return false;
      }
    } catch (err) {
      print(err);
      return false;
    }
  }
}
