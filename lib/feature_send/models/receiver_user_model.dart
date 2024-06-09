class ReceiverUserModel {
  int id;
  int userId;
  String firstName;
  String lastName;
  double amount;

  ReceiverUserModel(
      {required this.id,
      required this.userId,
      required this.firstName,
      required this.lastName,
      required this.amount});

  // Overriding toString method for better debugging
  @override
  String toString() {
    return 'User(id: $id, firstName: $firstName, lastName: $lastName)';
  }
}
