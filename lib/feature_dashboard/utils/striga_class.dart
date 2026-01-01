import 'package:get/get.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iban_to_bic/iban_to_bic.dart';

class StrigaClass {
  final UserController userController = Get.find();

  Future<Map<String, dynamic>> getWallet() async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('striga/get-wallets', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "userId": userController.user.value.id,
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Get.snackbar('Success', 'inf_WalletFetched'.tr);
        print(data['data']);
        return data['data']['strigaWalletsResponseBody']['accounts']['EUR']
            ['availableBalance'];
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return {};
      }
    } catch (err) {
      print(err);
    }
    throw Exception('Failed to retrieve payment token');
  }

  Future<String> initiateStrigaTransaction(
      int destinationUserId, String memo, double amount) async {
    const int CENT = 100;
    try {
      final response = await Supabase.instance.client.functions
          .invoke('striga/initiate-transaction', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "userId": userController.user.value.id,
        "destinationUserId": destinationUserId,
        "amount": (amount * CENT).toString(),
        "memo": memo,
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Get.snackbar('Success', 'inf_PaymentInitiated'.tr);
        return data['data']['strigaResponseBody']['challengeId'];
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return "";
      }
    } catch (err) {
      print(err);
      return "";
    }
  }

  Future<String> initiateStrigaSepaTransaction(
      String destinationIban, String memo, double amount) async {
    const int CENT = 100;
    final Bic bic = ibanToBic(destinationIban);
    try {
      final response = await Supabase.instance.client.functions
          .invoke('striga/initiate-sepa-transaction', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "userId": userController.user.value.id,
        "destinationIban": destinationIban,
        "destinationBic": bic.value,
        "amount": (amount * CENT).toString(),
        "memo": memo,
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Get.snackbar('Success', 'inf_PaymentInitiated'.tr);
        return data['data']['strigaResponseBody']['challengeId'];
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return "";
      }
    } catch (err) {
      print(err);
      return "";
    }
  }

  Future<bool> confirmStrigaTransaction(
      String challengeId, String verificationCode) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('striga/confirm-transaction', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "userId": userController.user.value.id,
        "challengeId": challengeId,
        "verificationCode": verificationCode,
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
