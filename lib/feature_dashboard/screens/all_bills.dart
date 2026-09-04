import 'package:flutter/material.dart';
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
import 'package:slickbill/shared_widgets/sb_segmented_control.dart';
import 'package:slickbill/theme/sb_colors.dart';

class AllBills extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 3);
    final currentTab = useState(0);
    NavigationController navigationController = Get.find();
    Get.put(UserController());
    Get.put(PaymentSetupController());

    useEffect(() {
      void listener() {
        currentTab.value = tabController.index;
        navigationController.billsTabIndex.value = tabController.index;
      }

      tabController.addListener(listener);
      return () => tabController.removeListener(listener);
    }, [tabController]);

    useEffect(() {
      final worker = ever<int>(navigationController.billsTabIndex, (index) {
        if (tabController.index != index) {
          tabController.animateTo(index);
        }
      });
      return worker.dispose;
    }, [tabController]);

    return Scaffold(
      backgroundColor: SbColors.surface,
      appBar: CustomAppbar(
        title: 'hd_Bills',
        showBrand: true,
        appbarIcon: IconButton(
          icon: FaIcon(
            FontAwesomeIcons.trash,
            size: 18,
            color: Theme.of(context).colorScheme.blue,
          ),
          onPressed: () => Get.to(() => AllTrashBills()),
          tooltip: 'Trash',
        ),
        showSettings: true,
      ),
      body: Column(
              children: [
                const PaymentSetupBanner(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: SbSegmentedControl(
                    index: currentTab.value,
                    onChanged: (i) => tabController.animateTo(i),
                    segments: [
                      SbSegment(label: 'hd_Received'.tr, icon: Icons.south_west),
                      SbSegment(label: 'hd_Sent'.tr, icon: Icons.north_east),
                      SbSegment(
                          label: 'hd_PublicInvoices'.tr, icon: Icons.link),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(controller: tabController, children: [
                    ReceivedBills(),
                    SentBills(),
                    PublicInvoices(),
                  ]),
                ),
              ],
            ),
    );
  }
}
