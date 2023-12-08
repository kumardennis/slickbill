import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_tickets/screens/tickets_folder_list.dart';

import '../../feature_dashboard/screens/all_bills.dart';
import '../../feature_navigation/getx_controllers/navigation_controller.dart';
import '../../feature_send/screens/send_invoice.dart';
import '../../feature_self_create/screens/open_create_self_invoice.dart';
import '../../feature_trashboard/screens/all_trash_bills.dart';

class HomeScreen extends StatelessWidget {
  final NavigationController navigationController =
      Get.put(NavigationController()); // Initialize controller

  final List<Widget> _pages = [
    // List of your page widgets
    AllBills(),
    const SendInvoice(),
    const OpenAndCreateSelfInvoice(),
    const TicketsFolderList(),
    const AllTrashBills()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() =>
          _pages[navigationController.currentIndex.value]), // Current page
      bottomNavigationBar: Obx(
        () => BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: navigationController.currentIndex.value,
          onTap: (index) => navigationController.changeIndex(index),
          backgroundColor: Theme.of(context).colorScheme.dark,
          selectedItemColor: Theme.of(context).colorScheme.light,
          unselectedItemColor: Theme.of(context).colorScheme.gray,
          items: const [
            BottomNavigationBarItem(
                icon: FaIcon(FontAwesomeIcons.list), label: ''),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.rocket),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.squarePlus),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.ticket),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: FaIcon(FontAwesomeIcons.trash),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}
