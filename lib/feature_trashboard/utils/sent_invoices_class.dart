import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../../feature_dashboard/models/invoice_model.dart';

class SentInvoicesClass {
  final UserController userController = Get.find();

  Future<List<InvoiceModel>?> getPrivateSentInvoices(accessToken) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
          'invoices/get-private-user-sent-obsolete-invoices',
          headers: {'Authorization': 'Bearer ${accessToken}'},
          body: {"privateUserId": userController.user.value.privateUserId});

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        List<InvoiceModel> invoices = (data['data'] as List)
            .map((e) => InvoiceModel.fromJson(e))
            .toList();

        print(invoices);

        return invoices;
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return null;
      }
    } catch (err) {
      print(err);
      return null;
    }
  }

  Future<double?> getPendingInvoicesSum(accessToken) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/get-private-user-sent-obsolete-invoices', headers: {
        'Authorization': 'Bearer ${accessToken}'
      }, body: {
        "privateUserId": userController.user.value.privateUserId,
        "status": "UNPAID"
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        List<InvoiceModel> invoices = (data['data'] as List)
            .map((e) => InvoiceModel.fromJson(e))
            .toList();

        print(invoices);

        double sum = 0;

        for (var invoice in invoices) {
          sum += invoice.amount;
        }
        return sum;
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return null;
      }
    } catch (err) {
      print(err);
      return null;
    }
  }

  Future<double?> getReceivedPaymentsThisMonth(accessToken) async {
    try {
      DateTime now = DateTime.now();

      DateTime firstDateOfMonth = DateTime(now.year, now.month, 1);
      DateTime lastDateOfMonth = DateTime(now.year, now.month + 1, 0);

      var dateRange = [
        DateFormat('yyyy-MM-dd').format(firstDateOfMonth),
        DateFormat('yyyy-MM-dd').format(lastDateOfMonth)
      ];

      final response = await Supabase.instance.client.functions
          .invoke('invoices/get-private-user-sent-obsolete-invoices', headers: {
        'Authorization': 'Bearer ${accessToken}'
      }, body: {
        "privateUserId": userController.user.value.privateUserId,
        "paidOnDateRange": dateRange
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        List<InvoiceModel> invoices = (data['data'] as List)
            .map((e) => InvoiceModel.fromJson(e))
            .toList();

        print(invoices);

        double sum = 0;

        for (var invoice in invoices) {
          sum += invoice.amount;
        }
        return sum;
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return null;
      }
    } catch (err) {
      print(err);
      return null;
    }
  }

  Future<void> updateInvoiceObsolete(invoiceId, isObsolete) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/update-invoice-obsolete', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: {
        "invoiceId": invoiceId,
        "isObsolete": isObsolete
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Get.snackbar('Success', 'inf_StatusUpdated'.tr);
      } else {
        Get.snackbar('Oops..', data['error'].toString());
      }
    } catch (err) {
      print(err);
    }
  }
}
