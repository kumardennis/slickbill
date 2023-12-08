import 'package:get/get.dart';

class NavigationController extends GetxController {
  var currentIndex = 0.obs;

  changeIndex(int value) => currentIndex.value = value;
}
