import 'package:get/get.dart';

class NavigationController extends GetxController {
  var currentIndex = 0.obs;
  var billsTabIndex = 0.obs;
  var exchangeTabIndex = 0.obs;

  changeIndex(int value) => currentIndex.value = value;

  void openUsernameSend() {
    exchangeTabIndex.value = 2;
    currentIndex.value = 1;
  }

  void openSentBills() {
    billsTabIndex.value = 1;
    currentIndex.value = 0;
  }
}
