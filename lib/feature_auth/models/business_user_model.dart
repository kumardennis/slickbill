import 'package:slickbill/feature_auth/models/user_model.dart';

class BusinessUserModel {
  final int id;
  final String fullName;
  final String publicName;
  final UserModel user;
  final String iban;
  final String bankAccountName;

  BusinessUserModel(this.id, this.fullName, this.publicName, this.iban,
      this.bankAccountName, this.user);
}
