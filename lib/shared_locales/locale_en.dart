import 'package:get/get.dart';
import 'package:slickbill/feature_nearby_transaction/locales/en_locale.dart';

import '../feature_Auth/locales/en_locale.dart';
import '../feature_Dashboard/locales/en_locale.dart';
import '../feature_self_create/locales/en_locale.dart';
import '../feature_send/locales/en_locale.dart';
import '../feature_tickets/locales/en_locale.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          'hello': 'Hello World',
          'lbl_Home': 'Home',
          'lbl_Ok': 'Ok',
          'lbl_Cancel': 'Cancel',
          'hd_Us': 'Us',
          'btn_Close': 'Close',
          'btn_Add': 'Add',
          'hd_Settings': 'Settings',
          'inf_Copied': 'Copied!',
          ...authLocales_EN,
          ...dashboardLocales_EN,
          ...selfCreateLocales_EN,
          ...sendLocales_EN,
          ...ticketLocales_EN,
          ...nearbyTransactionLocales_EN
        },
        'et_EE': {
          'hello': 'Hallo Welt',
        }
      };
}
