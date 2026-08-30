import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/payment_setup_controller.dart';
import 'package:slickbill/feature_dashboard/screens/public_invoices.dart';
import 'package:slickbill/feature_dashboard/screens/received_bills.dart';
import 'package:slickbill/feature_dashboard/screens/sent_bills.dart';
import 'package:slickbill/feature_dashboard/widgets/payment_setup_banner.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:slickbill/feature_trashboard/screens/all_trash_bills.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

import '../getx_controllers/intent_controller.dart';

class AllBills extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 3);
    NavigationController navigationController = Get.find();
    Get.put(UserController());
    final PaymentSetupController paymentSetupController =
        Get.put(PaymentSetupController());

    final filePath = useState<Uint8List?>(null);
    final checkingForIntent = useState<bool>(true);

    useEffect(() {
      paymentSetupController.refresh();
      return null;
    }, []);

    return (Scaffold(
      appBar: CustomAppbar(
        title: 'hd_Bills',
        appbarIcon: IconButton(
          icon: FaIcon(
            FontAwesomeIcons.trash,
            size: 20,
            color: Theme.of(context).colorScheme.blue,
          ),
          onPressed: () => Get.to(() => AllTrashBills()),
          tooltip: 'Trash',
        ),
        showSettings: true,
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
              Tab(text: 'hd_Received'.tr),
              Tab(text: 'hd_Sent'.tr),
              Tab(text: 'hd_PublicInvoices'.tr),
            ]),
      ),
      body: filePath.value != null
          ? const SizedBox()
          : Column(
              children: [
                const PaymentSetupBanner(),
                Expanded(
                  child: TabBarView(controller: tabController, children: [
                    ReceivedBills(),
                    SentBills(),
                    PublicInvoices(),
                  ]),
                ),
              ],
            ),
    ));
  }
}
