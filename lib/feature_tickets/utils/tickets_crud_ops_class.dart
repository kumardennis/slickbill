import 'package:get/get.dart';
import 'package:slickbill/feature_tickets/models/ticket_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';

class TicketsCrudOpsClass {
  final UserController userController = Get.find();

  Future<List<TicketModel>> getAllTickets(accessToken) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
          'tickets/get-private-user-tickets',
          headers: {'Authorization': 'Bearer ${accessToken}'},
          body: {"privateUserId": userController.user.value.privateUserId});

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        List<TicketModel> tickets =
            (data['data'] as List).map((e) => TicketModel.fromJson(e)).toList();

        print(tickets);

        return tickets;
      } else {
        Get.snackbar('Oops..', data['error'].toString());
        return [];
      }
    } catch (err) {
      print(err);
      return [];
    }
  }

  Future createTicket() async {}

  Future deleteTicket() async {}
}
