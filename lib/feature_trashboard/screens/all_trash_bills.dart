import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_trashboard/screens/received_bills.dart';
import 'package:slickbill/feature_trashboard/screens/sent_bills.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:slickbill/shared_widgets/sb_page_background.dart';
import 'package:slickbill/shared_widgets/sb_segmented_control.dart';

class AllTrashBills extends HookWidget {
  const AllTrashBills({super.key});

  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 2);
    final currentTab = useState(0);

    useEffect(() {
      void listener() {
        currentTab.value = tabController.index;
      }

      tabController.addListener(listener);
      return () => tabController.removeListener(listener);
    }, [tabController]);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppbar(
        title: 'hd_ObsoleteSlickBills'.tr,
        appbarIcon: null,
      ),
      body: SbPageBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: SbSegmentedControl(
                index: currentTab.value,
                onChanged: (i) => tabController.animateTo(i),
                segments: [
                  SbSegment(label: 'hd_Sent'.tr, icon: Icons.north_east),
                  SbSegment(label: 'hd_Received'.tr, icon: Icons.south_west),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [SentBills(), ReceivedBills()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
