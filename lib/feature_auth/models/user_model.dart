class UserModel {
  final int id;
  final String username;
  final String email;
  final String authUserId;
  final String accessToken;

  UserModel(
      this.id, this.username, this.email, this.authUserId, this.accessToken);
}

class BankAccount {
  final String bankName;
  final String iban;

  BankAccount({
    required this.bankName,
    required this.iban,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      bankName: json['bankName'] as String,
      iban: json['iban'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bankName': bankName,
      'iban': iban,
    };
  }

  @override
  String toString() {
    return 'BankAccount(bankName: $bankName, iban: $iban)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BankAccount &&
        other.bankName == bankName &&
        other.iban == iban;
  }

  @override
  int get hashCode => bankName.hashCode ^ iban.hashCode;
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
  final List<BankAccount>? ibans;
  final String? bankAccountName;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? publicName;
  final bool isPrivate;
  final String? strigaUserId;
  final String? sringaWalletId;

  ClientUserModel(
      this.id,
      this.privateUserId,
      this.businessUserId,
      this.username,
      this.email,
      this.authUserId,
      this.accessToken,
      this.iban,
      this.ibans,
      this.bankAccountName,
      this.firstName,
      this.lastName,
      this.fullName,
      this.publicName,
      this.isPrivate,
      this.strigaUserId,
      this.sringaWalletId);
}
