import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_tickets/widgets/custom_ticket.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:timeline_tile/timeline_tile.dart';

class TicketsFolderList extends HookWidget {
  const TicketsFolderList({super.key});

  @override
  Widget build(BuildContext context) {
    return (Scaffold(
      appBar: CustomAppbar(title: 'hd_Tickets'.tr, appbarIcon: null),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ListView(children: [
          TimelineTile(
            endChild: CustomTicket(),
          )
        ]),
      ),
    ));
  }
}
