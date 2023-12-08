import 'package:get/get.dart';

class IntentController extends GetxController {
  var intentExists = false.obs;

  loadIntent(bool newIntent) => intentExists.value = newIntent;
}
