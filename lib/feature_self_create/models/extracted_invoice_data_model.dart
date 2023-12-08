class ExtractedInvoiceDataModel {
  ExtractedInvoiceDataModel(
      {required this.iban,
      required this.merchantName,
      required this.invoiceNo,
      required this.totalAmount,
      required this.dueDate,
      required this.description,
      required this.referenceNumber,
      required this.category});
  late final List<Iban> iban;
  late final String merchantName;
  late final String invoiceNo;
  late final double totalAmount;
  late final String dueDate;
  late final String description;
  late final String referenceNumber;
  late final String category;

  ExtractedInvoiceDataModel.fromJson(Map<String, dynamic> json) {
    iban = List.from(json['iban']).map((e) => Iban.fromJson(e)).toList();
    merchantName = json['merchantName'];
    invoiceNo = json['invoiceNo'];
    totalAmount = json['totalAmount'].toDouble();
    dueDate = json['dueDate'];
    category = json['category'];
    description = json['description'];
    referenceNumber = json['referenceNumber'];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['iban'] = iban.map((e) => e.toJson()).toList();
    _data['merchantName'] = merchantName;
    _data['invoiceNo'] = invoiceNo;
    _data['totalAmount'] = totalAmount;
    _data['dueDate'] = dueDate;
    _data['description'] = description;
    _data['referenceNumber'] = referenceNumber;
    return _data;
  }
}

class Iban {
  Iban({
    required this.iban,
    required this.bankName,
  });
  late final String iban;
  late final String bankName;

  Iban.fromJson(Map<String, dynamic> json) {
    iban = json['iban'];
    bankName = json['bankName'];
  }

  Map<String, dynamic> toJson() {
    final _data = <String, dynamic>{};
    _data['iban'] = iban;
    _data['bankName'] = bankName;
    return _data;
  }
}
