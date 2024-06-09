import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_tickets/models/ticket_model.dart';
import 'package:slickbill/feature_tickets/utils/tickets_crud_ops_class.dart';
import 'package:slickbill/feature_tickets/widgets/custom_ticket.dart';
import 'package:slickbill/feature_tickets/widgets/custom_timeline_tile.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:timeline_tile/timeline_tile.dart';

import '../../feature_auth/getx_controllers/user_controller.dart';

class TicketsFolderList extends HookWidget {
  const TicketsFolderList({super.key});

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find();
    TicketsCrudOpsClass ticketsCrudOpsClass = TicketsCrudOpsClass();

    final allTickets = useState<List<TicketModel>>([]);

    Future getTickets() async {
      var response = await ticketsCrudOpsClass
          .getAllTickets(userController.user.value.accessToken);

      allTickets.value = response;
    }

    useEffect(() {
      getTickets();
    }, [userController.user.value.accessToken]);

    return (Scaffold(
      appBar: CustomAppbar(
        title: 'hd_Tickets'.tr,
        appbarIcon: null,
        tabBar: null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(
            children: allTickets.value
                .map((ticket) => CustomTimelineTile(
                      title: ticket.title,
                      description: ticket.description,
                      dateOfActivity: ticket.dateOfActivity,
                      category: ticket.category,
                      isInPast: false,
                    ))
                .toList()),
      ),
    ));
  }
}
