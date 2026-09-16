class UsersByUsername {
  UsersByUsername({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.users,
  });
  late final int id;
  late final String firstName;
  late final String lastName;
  late final Users users;

  UsersByUsername.fromJson(Map<String, dynamic> json) {
    id = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '') ?? 0;
    firstName = (json['firstName'] ?? '').toString();
    lastName = (json['lastName'] ?? '').toString();
    final rawUsers = json['users'];
    final usersJson = rawUsers is List && rawUsers.isNotEmpty
        ? rawUsers.first
        : rawUsers;
    users = Users.fromJson(
      usersJson is Map ? Map<String, dynamic>.from(usersJson) : const {},
    );
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['id'] = id;
    _data['firstName'] = firstName;
    _data['lastName'] = lastName;
    _data['users'] = users.toJson();
    return _data;
  }
}

class Users {
  Users({
    required this.username,
    required this.id,
  });
  late final String username;
  late final int id;

  Users.fromJson(Map<String, dynamic> json) {
    username = (json['username'] ?? '').toString();
    id = json['id'] is int
        ? json['id'] as int
        : int.tryParse(json['id']?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['username'] = username;
    _data['id'] = id;
    return _data;
  }
}
