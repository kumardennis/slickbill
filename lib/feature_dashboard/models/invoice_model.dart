class InvoiceModel {
  InvoiceModel({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.amount,
    this.data,
    required this.description,
    this.rawInvoiceId,
    required this.senderName,
    required this.senderIban,
    required this.deadline,
    required this.invoiceNo,
    this.originalInvoiceNo,
    required this.isSeen,
    this.referenceNo,
    required this.receivers,
    required this.senders,
    required this.category,
  });
  late final int id;
  late final String createdAt;
  late final String updatedAt;
  late final int? senderId;
  late final int receiverId;
  late final String status;
  late final double amount;
  late final Map? data;
  late final String description;
  late final int? rawInvoiceId;
  late final String senderName;
  late final String? senderIban;
  late final String deadline;
  late final String? paidOnDate;
  late final String invoiceNo;
  late final String? originalInvoiceNo;
  late final bool isSeen;
  late final String? referenceNo;
  late final Receivers receivers;
  late final Senders? senders;
  late final String? category;

  InvoiceModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    senderId = json['senderId'];
    receiverId = json['receiverId'];
    category = json['category'];
    status = json['status'];
    amount = json['amount'].toDouble();
    data = json['data'];
    description = json['description'];
    rawInvoiceId = json['rawInvoiceId'];
    senderName = json['senderName'];
    senderIban = json['senderIban'];
    deadline = json['deadline'];
    paidOnDate = json['paidOnDate'];
    invoiceNo = json['invoiceNo'];
    originalInvoiceNo = json['originalInvoiceNo'];
    isSeen = json['isSeen'];
    referenceNo = json['referenceNo'];
    receivers = Receivers.fromJson(json['receivers']);
    senders =
        json['senders'] != null ? Senders.fromJson(json['senders']) : null;
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['id'] = id;
    _data['created_at'] = createdAt;
    _data['updated_at'] = updatedAt;
    _data['senderId'] = senderId;
    _data['receiverId'] = receiverId;
    _data['status'] = status;
    _data['amount'] = amount;
    _data['data'] = data;
    _data['description'] = description;
    _data['rawInvoiceId'] = rawInvoiceId;
    _data['senderName'] = senderName;
    _data['deadline'] = deadline;
    _data['invoiceNo'] = invoiceNo;
    _data['originalInvoiceNo'] = originalInvoiceNo;
    _data['isSeen'] = isSeen;
    _data['referenceNo'] = referenceNo;
    _data['receivers'] = receivers.toJson();
    _data['senders'] = senders?.toJson();
    return _data;
  }
}

class Receivers {
  Receivers({
    required this.id,
    required this.createdAt,
    required this.privateUserId,
    this.businessUserId,
    required this.privateUsers,
    this.businessUsers,
  });
  late final int id;
  late final String createdAt;
  late final int privateUserId;
  late final int? businessUserId;
  late final PrivateUsers? privateUsers;
  late final BusinessUsers? businessUsers;

  Receivers.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    privateUserId = json['privateUserId'];
    businessUserId = json['businessUserId'];
    privateUsers = PrivateUsers.fromJson(json['private_users']);
    businessUsers = json['businessUsers'];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['id'] = id;
    _data['created_at'] = createdAt;
    _data['privateUserId'] = privateUserId;
    _data['businessUserId'] = businessUserId;
    _data['private_users'] = privateUsers?.toJson();
    _data['business_users'] = businessUsers;
    return _data;
  }
}

class PrivateUsers {
  PrivateUsers({
    required this.id,
    required this.createdAt,
    required this.firstName,
    required this.lastName,
    required this.userId,
    required this.iban,
    required this.bankAccountName,
  });
  late final int id;
  late final String createdAt;
  late final String firstName;
  late final String lastName;
  late final int userId;
  late final String iban;
  late final String bankAccountName;

  PrivateUsers.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    firstName = json['firstName'];
    lastName = json['lastName'];
    userId = json['userId'];
    iban = json['iban'];
    bankAccountName = json['bankAccountName'];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['id'] = id;
    _data['created_at'] = createdAt;
    _data['firstName'] = firstName;
    _data['lastName'] = lastName;
    _data['userId'] = userId;
    _data['iban'] = iban;
    _data['bankAccountName'] = bankAccountName;
    return _data;
  }
}

class BusinessUsers {
  BusinessUsers({
    required this.id,
    required this.createdAt,
    required this.fullName,
    required this.publicName,
    required this.userId,
    required this.iban,
    required this.bankAccountName,
  });
  late final int id;
  late final String createdAt;
  late final String fullName;
  late final String publicName;
  late final int userId;
  late final String iban;
  late final String bankAccountName;

  BusinessUsers.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    fullName = json['fullName'];
    publicName = json['publicName'];
    userId = json['userId'];
    iban = json['iban'];
    bankAccountName = json['bankAccountName'];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['id'] = id;
    _data['created_at'] = createdAt;
    _data['firstName'] = fullName;
    _data['lastName'] = publicName;
    _data['userId'] = userId;
    _data['iban'] = iban;
    _data['bankAccountName'] = bankAccountName;
    return _data;
  }
}

class Senders {
  Senders({
    required this.id,
    required this.createdAt,
    required this.privateUserId,
    this.businessUserId,
    required this.privateUsers,
  });
  late final int id;
  late final String createdAt;
  late final int privateUserId;
  late final int? businessUserId;
  late final PrivateUsers? privateUsers;

  Senders.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    createdAt = json['created_at'];
    privateUserId = json['privateUserId'];
    businessUserId = json['businessUserId'];
    privateUsers = PrivateUsers.fromJson(json['private_users']);
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['id'] = id;
    _data['created_at'] = createdAt;
    _data['privateUserId'] = privateUserId;
    _data['businessUserId'] = businessUserId;
    _data['private_users'] = privateUsers?.toJson();
    return _data;
  }
}
