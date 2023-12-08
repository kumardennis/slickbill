class UserModel {
  final int id;
  final String username;
  final String email;
  final String authUserId;
  final String accessToken;

  UserModel(
      this.id, this.username, this.email, this.authUserId, this.accessToken);
}

class ClientUserModel {
  final int id;
  final int? privateUserId;
  final int? businessUserId;
  final String username;
  final String email;
  final String authUserId;
  final String accessToken;
  final String? iban;
  final String? bankAccountName;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? publicName;
  final bool isPrivate;

  ClientUserModel(
      this.id,
      this.privateUserId,
      this.businessUserId,
      this.username,
      this.email,
      this.authUserId,
      this.accessToken,
      this.iban,
      this.bankAccountName,
      this.firstName,
      this.lastName,
      this.fullName,
      this.publicName,
      this.isPrivate);
}
