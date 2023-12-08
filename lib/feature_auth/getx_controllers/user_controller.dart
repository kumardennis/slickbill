import 'package:get/get.dart';

import '../models/user_model.dart';

class UserController extends GetxController {
  var user = ClientUserModel(
          0, null, null, '', '', '', '', '', '', '', '', '', '', true)
      .obs;

  loadUser(ClientUserModel updatedUser) => user.value = updatedUser;
}
