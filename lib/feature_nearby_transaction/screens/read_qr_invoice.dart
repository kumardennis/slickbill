import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:pulsator/pulsator.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReadQrInvoice extends HookWidget {
  const ReadQrInvoice({super.key});

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find();
    final NavigationController navigationController = Get.find();

    final nfcStarted = useState(false);

    final supabase = Supabase.instance.client;

    final _flutterNfcHcePlugin = FlutterNfcHce();

    Future<void> startNFCWriting() async {
      bool? isNfcHceSupported = await _flutterNfcHcePlugin.isNfcHceSupported();

      bool? isNfcEnabled = await _flutterNfcHcePlugin.isNfcEnabled();

      if (!isNfcEnabled || !isNfcHceSupported) {
        Get.snackbar('Ooops...', 'NFC not supported');
        return;
      }

      try {
        nfcStarted.value = true;
        var content =
            '${userController.user.value.privateUserId}-${userController.user.value.firstName}';

        await _flutterNfcHcePlugin.startNfcHce(content);

        Get.snackbar('NFC Active',
            'Your device is ready to be scanned. Hold it near another NFC device.');

        await Future.delayed(const Duration(seconds: 10), () async {
          await _flutterNfcHcePlugin.stopNfcHce();
          nfcStarted.value = false;
        });
      } catch (e) {
        debugPrint('Error in startNFCWriting: $e');
      }
    }

    useEffect(() {
      startNfc() async {
        await startNFCWriting();
      }

      startNfc();

      supabase
          .channel('public:receivers')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'receivers',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'privateUserId',
              value: userController.user.value.isPrivate
                  ? userController.user.value.privateUserId
                  : userController.user.value.businessUserId,
            ),
            callback: (payload) {
              debugPrint('------------Change received: ${payload.toString()}');

              if (payload.newRecord["privateUserId"] ==
                  userController.user.value.privateUserId) {
                _flutterNfcHcePlugin.stopNfcHce();
                nfcStarted.value = false;

                Get.snackbar(
                    "Slickbill Received!", "A new slickbill is received!");
                Navigator.pop(context);
                navigationController.changeIndex(0);
              }
            },
          )
          .subscribe();

      return () => _flutterNfcHcePlugin.stopNfcHce();
    }, []);

    return Scaffold(
      appBar: CustomAppbar(title: 'hd_NfcTransaction'.tr, appbarIcon: null),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Pulsator(
                    style:
                        PulseStyle(color: Theme.of(context).colorScheme.blue),
                    count: 4,
                    duration: Duration(seconds: 3),
                    repeat: 0,
                  ),
                  Center(
                    child: Text(""),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
