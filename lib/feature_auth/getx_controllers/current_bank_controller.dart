import 'package:get/get.dart';

import '../models/user_model.dart';

class CurrentBankController extends GetxController {
  var current = BankAccount(bankName: '', iban: '').obs;

  loadCurrentBank(BankAccount updatedBank) => current.value = updatedBank;
}
