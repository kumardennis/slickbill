import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';
import '../models/invoice_list_query.dart';
import '../models/invoice_model.dart';

class SentInvoicesClass {
  final UserController userController = Get.find();

  Future<List<InvoiceModel>?> getPrivateSentInvoices({
    InvoiceListQuery? query,
    bool openOnly = false,
    DateTime? paidInMonth,
    bool silent = false,
  }) async {
    try {
      final body = <String, dynamic>{
        "privateUserId": userController.user.value.privateUserId,
        if (openOnly) "openOnly": true,
        if (query != null) ...query.toRequestBody(),
        if (paidInMonth != null) ...{
          "status": "PAID",
          "paidOnDateRange": InvoiceListQuery(
            month: paidInMonth,
            status: InvoiceStatusFilter.paid,
          ).paidOnDateRange,
        },
      };

      final response = await Supabase.instance.client.functions
          .invoke('invoices/get-private-user-sent-invoices', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
      }, body: body);

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        List<InvoiceModel> invoices = (data['data'] as List)
            .map((e) => InvoiceModel.fromJson(e))
            .toList();

        if (query != null) {
          invoices = invoices
              .where((invoice) => query.matches(
                    status: invoice.status,
                    createdAt: invoice.createdAt,
                    paidOnDate: invoice.paidOnDate,
                    deadline: invoice.deadline,
                  ))
              .toList();
        }

        print(invoices);

        return invoices;
      } else {
        if (!silent) {
          Get.snackbar('Oops..', data['error'].toString());
        }
        return null;
      }
    } catch (err) {
      print(err);
      return null;
    }
  }

  Future<double?> getOpenInvoicesSum({InvoiceListQuery? period}) async {
    final invoices = await getPrivateSentInvoices(
      openOnly: true,
      query: period?.periodOnly,
      silent: true,
    );
    if (invoices == null) return null;
    return invoices
        .where((invoice) {
          final status = invoice.status.trim().toUpperCase();
          return status != 'PAID';
        })
        .fold<double>(0.0, (sum, invoice) => sum + invoice.amount);
  }

  Future<double?> getPaidInPeriod(InvoiceListQuery period) async {
    if (period.allTime) {
      final invoices = await getPrivateSentInvoices(
        query: InvoiceListQuery(
          month: period.month,
          status: InvoiceStatusFilter.paid,
          allTime: true,
        ),
        silent: true,
      );
      if (invoices == null) return null;
      return invoices.fold<double>(0.0, (sum, invoice) => sum + invoice.amount);
    }
    return getPaidInMonth(period.monthStart);
  }

  Future<double?> getPaidInMonth(DateTime month) async {
    final invoices = await getPrivateSentInvoices(
      paidInMonth: month,
      silent: true,
    );
    if (invoices == null) return null;
    return invoices.fold<double>(0.0, (sum, invoice) => sum + invoice.amount);
  }

  Future<double?> getPendingInvoicesSum() async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('invoices/get-private-user-sent-invoices', headers: {
        'Authorization': 'Bearer ${userController.user.value.accessToken}'
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
          .invoke('invoices/get-private-user-sent-invoices', headers: {
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

  Future<String?> remindInvoice(InvoiceModel invoice) async {
    final receiverUserId = invoice.receivers.privateUsers?.userId;
    if (receiverUserId == null || receiverUserId <= 0) {
      Get.snackbar('Oops..', 'Receiver is missing');
      return null;
    }

    final senderName = userController.user.value.requestDisplayName;
    final amount = NumberFormat.currency(symbol: '€').format(invoice.amount);
    final due = invoice.deadline.length >= 10
        ? invoice.deadline.substring(0, 10)
        : invoice.deadline;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isOverdue = due.isNotEmpty && due.compareTo(today) < 0;
    final isDueToday = due == today;

    final title = isDueToday ? 'Payment due today' : 'Payment reminder';
    final body = isOverdue
        ? '${senderName.isEmpty ? 'Someone' : senderName} is waiting for $amount. This slickbill is overdue (due $due).'
        : isDueToday
            ? '${senderName.isEmpty ? 'Someone' : senderName} is waiting for $amount. Due today.'
            : '${senderName.isEmpty ? 'Someone' : senderName} is waiting for $amount${due.isNotEmpty ? '. Due $due' : ''}.';

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'notifications/send-notification',
        headers: {
          'Authorization': 'Bearer ${userController.user.value.accessToken}'
        },
        body: {
          'userId': receiverUserId,
          'type': 'payment_reminder',
          'invoiceId': invoice.id,
          'title': title,
          'body': body,
        },
      );

      final data = response.data;
      if (data is! Map || data['isRequestSuccessfull'] != true) {
        Get.snackbar('Oops..', _errorText(data is Map ? data['error'] : data));
        return null;
      }

      final remindedAt = DateTime.now().toUtc().toIso8601String();
      try {
        await Supabase.instance.client.from('digital_invoices').update({
          'lastRemindedAt': remindedAt,
        }).eq('id', invoice.id);
      } catch (err) {
        print('lastRemindedAt update skipped: $err');
      }

      return remindedAt;
    } catch (err) {
      print(err);
      Get.snackbar('Oops..', _errorText(err));
      return null;
    }
  }

  String _errorText(dynamic error) {
    if (error == null) return 'Could not send reminder';
    if (error is String) {
      final trimmed = error.trim();
      if (trimmed.isEmpty || trimmed == '{}') return 'Could not send reminder';
      return trimmed;
    }
    if (error is Map) {
      final message = error['message'] ?? error['error'] ?? error['details'];
      if (message != null) return _errorText(message);
    }
    final text = error.toString().trim();
    if (text.isEmpty || text == '{}') return 'Could not send reminder';
    return text;
  }
}
