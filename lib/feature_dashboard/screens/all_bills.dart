import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/screens/received_bills.dart';
import 'package:slickbill/feature_dashboard/screens/sent_bills.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

import '../getx_controllers/intent_controller.dart';

class AllBills extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(initialLength: 2);
    NavigationController navigationController = Get.find();
    UserController userController = Get.find();

    IntentController intentController = Get.put(IntentController());

    var tabIndex = useState(0);

    final filePath = useState<Uint8List?>(null);
    final checkingForIntent = useState<bool>(true);
    final intentAlreadyHandled = useState<bool>(false);

    const platform = const MethodChannel('com.example.slickbill/getPdfBytes');

    Future<Uint8List?> _getFilePath() async {
      try {
        final Uint8List? result = await platform.invokeMethod('getPdfBytes');
        print('FLUTTERBYTES $result');
        return result;
      } on PlatformException catch (e) {
        print("Failed to get file path: '${e.message}'.");
        return null;
      }
    }

    useEffect(() {
      if (!kIsWeb && !intentController.intentExists.value) {
        _getFilePath().then((value) {
          filePath.value = value;

          intentController.loadIntent(value != null);

          if (value != null) {
            filePath.value = null;
            intentController.loadIntent(true);
            navigationController.changeIndex(2);
          }

          checkingForIntent.value = false;
        });
      } else {
        checkingForIntent.value = false;
      }

      return;
    }, const []);

    return (Scaffold(
      appBar: CustomAppbar(
        title:
            '${'hd_YourSlickBills'.tr} @${userController.user.value.username}',
        appbarIcon: null,
        showSettings: true,
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
      body: checkingForIntent.value
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : filePath.value != null
              ? const SizedBox()
              : TabBarView(
                  controller: tabController,
                  children: [SentBills(), ReceivedBills()]),
    ));
  }
}
