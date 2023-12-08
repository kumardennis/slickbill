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
    id = json['id'];
    firstName = json['firstName'];
    lastName = json['lastName'];
    users = Users.fromJson(json['users']);
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
    username = json['username'];
    id = json['id'];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['username'] = username;
    _data['id'] = id;
    return _data;
  }
}
