class TicketModel {
  TicketModel({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.description,
    required this.dateOfActivity,
    required this.category,
    this.qrCodeLink,
    required this.privateUserId,
  });
  late final int id;
  late final String createdAt;
  late final String title;
  late final String description;
  late final String dateOfActivity;
  late final String category;
  late final String? qrCodeLink;
  late final int privateUserId;

  TicketModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    title = json['title'];
    description = json['description'];
    dateOfActivity = json['dateOfActivity'];
    category = json['category'];
    qrCodeLink = json['qrCodeLink'];
    privateUserId = json['privateUserId'];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['id'] = id;
    _data['created_at'] = createdAt;
    _data['title'] = title;
    _data['description'] = description;
    _data['dateOfActivity'] = dateOfActivity;
    _data['category'] = category;
    _data['qrCodeLink'] = qrCodeLink;
    _data['privateUserId'] = privateUserId;
    return _data;
  }
}
