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

class AllBills extends HookWidget {
  @override
  Widget build(BuildContext context) {
    NavigationController navigationController = Get.find();
    Get.put(UserController());
    Get.put(PaymentSetupController());
    final currentTab = useState(navigationController.billsTabIndex.value);
    final visitedTabs = useState(<int>{currentTab.value});

    void selectTab(int index) {
      if (currentTab.value != index) {
        currentTab.value = index;
      }
      if (!visitedTabs.value.contains(index)) {
        visitedTabs.value = {...visitedTabs.value, index};
      }
      if (navigationController.billsTabIndex.value != index) {
        navigationController.billsTabIndex.value = index;
      }
    }

    useEffect(() {
      final worker = ever<int>(navigationController.billsTabIndex, (index) {
        selectTab(index);
      });
      return worker.dispose;
    }, []);

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    onChanged: selectTab,
                    segments: [
                      SbSegment(label: 'hd_Received'.tr, icon: Icons.south_west),
                      SbSegment(label: 'hd_Sent'.tr, icon: Icons.north_east),
                      SbSegment(
                          label: 'hd_PublicInvoices'.tr, icon: Icons.link),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (visitedTabs.value.contains(0))
                        Offstage(
                          offstage: currentTab.value != 0,
                          child: TickerMode(
                            enabled: currentTab.value == 0,
                            child: const ReceivedBills(),
                          ),
                        ),
                      if (visitedTabs.value.contains(1))
                        Offstage(
                          offstage: currentTab.value != 1,
                          child: TickerMode(
                            enabled: currentTab.value == 1,
                            child: SentBills(),
                          ),
                        ),
                      if (visitedTabs.value.contains(2))
                        Offstage(
                          offstage: currentTab.value != 2,
                          child: TickerMode(
                            enabled: currentTab.value == 2,
                            child: PublicInvoices(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
