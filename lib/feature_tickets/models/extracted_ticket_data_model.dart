class ExtractedTicketDataModel {
  ExtractedTicketDataModel({
    required this.title,
    required this.category,
    required this.description,
    required this.dateOfActivity,
    required this.qrCodeUri,
  });
  late final String title;
  late final String category;
  late final String description;
  late final String dateOfActivity;
  late final String qrCodeUri;

  ExtractedTicketDataModel.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    category = json['category'];
    description = json['description'];
    dateOfActivity = json['dateOfActivity'];
    qrCodeUri = json['qrCodeUri'];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['title'] = title;
    _data['category'] = category;
    _data['description'] = description;
    _data['dateOfActivity'] = dateOfActivity;
    _data['qrCodeUri'] = qrCodeUri;
    return _data;
  }
}
