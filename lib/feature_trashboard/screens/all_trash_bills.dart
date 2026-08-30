import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_trashboard/screens/received_bills.dart';
import 'package:slickbill/feature_trashboard/screens/sent_bills.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

class AllTrashBills extends HookWidget {
  const AllTrashBills({super.key});

  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 2);

    return (Scaffold(
      appBar: CustomAppbar(
        title: 'hd_ObsoleteSlickBills'.tr,
        appbarIcon: null,
        tabBar: TabBar(
            indicatorColor: Theme.of(context).colorScheme.blue,
            labelColor: Theme.of(context).colorScheme.blue,
            unselectedLabelColor: Theme.of(context).colorScheme.gray,
            labelStyle: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
            unselectedLabelStyle: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            controller: tabController,
            tabs: [
              Tab(text: 'hd_Sent'.tr),
              Tab(text: 'hd_Received'.tr),
            ]),
      ),
      body: TabBarView(
          controller: tabController, children: [SentBills(), ReceivedBills()]),
    ));
  }
}
