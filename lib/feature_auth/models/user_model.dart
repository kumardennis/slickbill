class UserModel {
  final int id;
  final String username;
  final String email;
  final String authUserId;
  final String accessToken;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.authUserId,
    required this.accessToken,
  });

  UserModel.empty()
      : id = 0,
        username = '',
        email = '',
        authUserId = '',
        accessToken = '';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      authUserId: json['authUserId'] as String,
      accessToken: json['accessToken'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'authUserId': authUserId,
      'accessToken': accessToken,
    };
  }
}

class BankAccount {
  final String iban;
  final String bankName; // institution, e.g. "LHV Bank AS"
  final String? bankAccountName; // per-account name/alias
  final bool isPrimary;

  BankAccount({
    required this.iban,
    required this.bankName,
    required this.bankAccountName,
    this.isPrimary = false,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      iban: json['iban'] as String,
      bankName: json['bankName'] as String? ?? '',
      bankAccountName: json['bankAccountName'] as String? ?? '',
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'iban': iban,
      'bankName': bankName,
      'bankAccountName': bankAccountName,
      'isPrimary': isPrimary,
    };
  }

  @override
  String toString() {
    return 'BankAccount(iban: $iban, bankName: $bankName, '
        'bankAccountName: $bankAccountName, isPrimary: $isPrimary)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BankAccount &&
        other.iban == iban &&
        other.bankName == bankName &&
        other.bankAccountName == bankAccountName &&
        other.isPrimary == isPrimary;
  }

  @override
  int get hashCode =>
      iban.hashCode ^
      bankName.hashCode ^
      bankAccountName.hashCode ^
      isPrimary.hashCode;
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
  final String? strigaWalletId;
  final String? cdpWalletId;

  ClientUserModel({
    required this.id,
    this.privateUserId,
    this.businessUserId,
    required this.username,
    required this.email,
    required this.authUserId,
    required this.accessToken,
    this.iban,
    this.ibans,
    this.bankAccountName,
    this.firstName,
    this.lastName,
    this.fullName,
    this.publicName,
    required this.isPrivate,
    this.strigaUserId,
    this.strigaWalletId,
    this.cdpWalletId,
  });

  ClientUserModel.empty()
      : id = 0,
        privateUserId = null,
        businessUserId = null,
        username = '',
        email = '',
        authUserId = '',
        accessToken = '',
        iban = null,
        ibans = null,
        bankAccountName = null,
        firstName = null,
        lastName = null,
        fullName = null,
        publicName = null,
        isPrivate = true,
        strigaUserId = null,
        strigaWalletId = null,
        cdpWalletId = null;

  factory ClientUserModel.fromJson(Map<String, dynamic> json) {
    return ClientUserModel(
      id: json['id'] as int,
      privateUserId: json['privateUserId'] as int?,
      businessUserId: json['businessUserId'] as int?,
      username: json['username'] as String,
      email: json['email'] as String,
      authUserId: json['authUserId'] as String,
      accessToken: json['accessToken'] as String,
      iban: json['iban'] as String?,
      ibans: json['ibans'] != null
          ? (json['ibans'] as List)
              .map((i) => BankAccount.fromJson(i as Map<String, dynamic>))
              .toList()
          : null,
      bankAccountName: json['bankAccountName'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      fullName: json['fullName'] as String?,
      publicName: json['publicName'] as String?,
      isPrivate: json['isPrivate'] as bool,
      strigaUserId: json['strigaUserId'] as String?,
      strigaWalletId: json['strigaWalletId'] as String?,
      cdpWalletId: json['cdpWalletId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'privateUserId': privateUserId,
      'businessUserId': businessUserId,
      'username': username,
      'email': email,
      'authUserId': authUserId,
      'accessToken': accessToken,
      'iban': iban,
      'ibans': ibans?.map((i) => i.toJson()).toList(),
      'bankAccountName': bankAccountName,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'publicName': publicName,
      'isPrivate': isPrivate,
      'strigaUserId': strigaUserId,
      'strigaWalletId': strigaWalletId,
    };
  }

  ClientUserModel copyWith({
    int? id,
    int? privateUserId,
    int? businessUserId,
    String? username,
    String? email,
    String? authUserId,
    String? accessToken,
    String? iban,
    List<BankAccount>? ibans,
    String? bankAccountName,
    String? firstName,
    String? lastName,
    String? fullName,
    String? publicName,
    bool? isPrivate,
    String? strigaUserId,
    String? sringaWalletId,
    String? cdpWalletId,
  }) {
    return ClientUserModel(
      id: id ?? this.id,
      privateUserId: privateUserId ?? this.privateUserId,
      businessUserId: businessUserId ?? this.businessUserId,
      username: username ?? this.username,
      email: email ?? this.email,
      authUserId: authUserId ?? this.authUserId,
      accessToken: accessToken ?? this.accessToken,
      iban: iban ?? this.iban,
      ibans: ibans ?? this.ibans,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      publicName: publicName ?? this.publicName,
      isPrivate: isPrivate ?? this.isPrivate,
      strigaUserId: strigaUserId ?? this.strigaUserId,
      strigaWalletId: strigaWalletId ?? this.strigaWalletId,
      cdpWalletId: cdpWalletId ?? this.cdpWalletId,
    );
  }
}

class SupabaseUserModel {
  final int id;
  final String email;
  final String username;
  final String authUserId;
  final String createdAt;
  final int? phoneNumber;
  final String? strigaUserId;
  final String? strigaWalletId;
  final String? phoneCountryCode;
  final String? cdpWalletId;

  SupabaseUserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.authUserId,
    required this.createdAt,
    this.phoneNumber,
    this.strigaUserId,
    this.strigaWalletId,
    this.cdpWalletId,
    this.phoneCountryCode,
  });

  factory SupabaseUserModel.fromJson(Map<String, dynamic> json) {
    return SupabaseUserModel(
      id: json['id'] as int,
      email: json['email'] as String,
      username: json['username'] as String,
      authUserId: json['authUserId'] as String,
      createdAt: json['created_at'] as String,
      phoneNumber: json['phoneNumber'] as int?,
      strigaUserId: json['strigaUserId'] as String?,
      strigaWalletId: json['strigaWalletId'] as String?,
      phoneCountryCode: json['phoneCountryCode'] as String?,
      cdpWalletId: json['cdpWalletId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'authUserId': authUserId,
      'created_at': createdAt,
      'phoneNumber': phoneNumber,
      'strigaUserId': strigaUserId,
      'strigaWalletId': strigaWalletId,
      'phoneCountryCode': phoneCountryCode,
      'cdpWalletId': cdpWalletId,
    };
  }
}
