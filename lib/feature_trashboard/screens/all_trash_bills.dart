import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_trashboard/screens/received_bills.dart';
import 'package:slickbill/feature_trashboard/screens/sent_bills.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

class AllTrashBills extends HookWidget {
  const AllTrashBills({super.key});

  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 2);

    var tabIndex = useState(0);

    final filePath = useState<Uint8List?>(null);
    final checkingForIntent = useState<bool>(true);

    return (Scaffold(
      appBar: CustomAppbar(
        title: 'hd_ObsoleteSlickBills'.tr,
        appbarIcon: null,
        tabBar: TabBar(
            indicatorColor: Theme.of(context).colorScheme.blue,
            onTap: (value) {
              tabIndex.value = value;
            },
            controller: tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'hd_Sent'.tr,
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(
                              color: tabIndex.value == 0
                                  ? Theme.of(context).colorScheme.blue
                                  : Theme.of(context).colorScheme.gray),
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    FaIcon(FontAwesomeIcons.squareCaretUp,
                        size: 20,
                        color: tabIndex.value == 0
                            ? Theme.of(context).colorScheme.blue
                            : Theme.of(context).colorScheme.gray)
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'hd_Received'.tr,
                      style: Theme.of(context)
                          .textTheme
                          .displayMedium
                          ?.copyWith(
                              color: tabIndex.value == 1
                                  ? Theme.of(context).colorScheme.blue
                                  : Theme.of(context).colorScheme.gray),
                    ),
                    const SizedBox(
                      width: 5,
                    ),
                    FaIcon(FontAwesomeIcons.squareCaretDown,
                        size: 20,
                        color: tabIndex.value == 1
                            ? Theme.of(context).colorScheme.blue
                            : Theme.of(context).colorScheme.gray)
                  ],
                ),
              )
            ]),
      ),
      body: TabBarView(
          controller: tabController, children: [SentBills(), ReceivedBills()]),
    ));
  }
}
