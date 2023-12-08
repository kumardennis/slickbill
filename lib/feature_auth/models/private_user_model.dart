import 'package:slickbill/feature_auth/models/user_model.dart';

class PrivateUserModel {
  final int id;
  final String firstName;
  final String lastName;
  final UserModel user;
  final String iban;
  final String bankAccountName;

  PrivateUserModel(this.id, this.firstName, this.lastName, this.iban,
      this.bankAccountName, this.user);
}
