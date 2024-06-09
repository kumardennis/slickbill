import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:pulsator/pulsator.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';

class MakeNfcAvailable extends HookWidget {
  const MakeNfcAvailable({super.key});

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find();

    final nfcStarted = useState(false);

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

        debugPrint("---------------------------CONTENTTTTT");
        debugPrint(content);

        await _flutterNfcHcePlugin.startNfcHce(content);

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
                    child: FaIcon(
                      FontAwesomeIcons.nfcSymbol,
                      color: Theme.of(context).colorScheme.light,
                    ),
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
