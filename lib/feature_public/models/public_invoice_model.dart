import 'package:slickbill/feature_dashboard/models/invoice_model.dart';

class PublicInvoiceModel {
  final int id;
  final String? publicToken;
  final double amount;
  final String? description;
  final String? category;
  final String status;
  final String? deadline;
  final String? senderIban;
  final String? senderName;
  final String? referenceNo;
  final String? originalInvoiceNo;
  final int? senderPrivateUserId;
  final int? receiverPrivateUserId;
  final int viewCount;
  final int claimCount;
  final dynamic data;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isObsolete;
  final String? paidOnDate;
  final List<ClaimedInvoice>? claimedInvoices;

  PublicInvoiceModel({
    required this.id,
    required this.publicToken,
    required this.amount,
    this.description,
    this.category,
    required this.status,
    this.deadline,
    this.senderIban,
    this.senderName,
    this.referenceNo,
    this.originalInvoiceNo,
    this.senderPrivateUserId,
    this.receiverPrivateUserId,
    required this.viewCount,
    required this.claimCount,
    this.data,
    required this.createdAt,
    required this.updatedAt,
    required this.isObsolete,
    this.paidOnDate,
    this.claimedInvoices,
  });

  factory PublicInvoiceModel.fromJson(Map<String, dynamic> json) {
    print('🔵 [PublicInvoiceModel] Starting parse...');
    print('🔵 [PublicInvoiceModel] JSON keys: ${json.keys}');

    try {
      print('🔵 [PublicInvoiceModel] Parsing id: ${json['id']}');
      final id = json['id'];

      print(
          '🔵 [PublicInvoiceModel] Parsing publicToken: ${json['publicToken']} or ${json['public_token']}');
      final publicToken = json['publicToken'] ?? json['public_token'] ?? '';

      print('🔵 [PublicInvoiceModel] Parsing amount: ${json['amount']}');
      final amount = (json['amount'] ?? 0).toDouble();

      print('🔵 [PublicInvoiceModel] Parsing basic fields...');
      final description = json['description'];
      final category = json['category'];
      final status = json['status'] ?? 'UNPAID';
      final deadline = json['deadline'];

      print('🔵 [PublicInvoiceModel] Parsing sender fields...');
      final senderIban = json['senderIban'] ?? json['sender_iban'];
      final senderName = json['senderName'] ?? json['sender_name'];
      final referenceNo = json['referenceNo'] ?? json['reference_no'];
      final originalInvoiceNo =
          json['originalInvoiceNo'] ?? json['original_invoice_no'];

      print('🔵 [PublicInvoiceModel] Parsing user IDs...');
      final senderPrivateUserId =
          json['senderPrivateUserId'] ?? json['sender_private_user_id'];
      final receiverPrivateUserId =
          json['receiverPrivateUserId'] ?? json['receiver_private_user_id'];

      print('🔵 [PublicInvoiceModel] Parsing counts...');
      final viewCount = json['viewCount'] ?? json['view_count'] ?? 0;
      final claimCount = json['claimCount'] ?? json['claim_count'] ?? 0;

      print('🔵 [PublicInvoiceModel] Parsing data...');
      final data = json['data'];

      print('🔵 [PublicInvoiceModel] Parsing dates...');
      final createdAt = json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : DateTime.now());

      final updatedAt = json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : (json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : DateTime.now());

      print('🔵 [PublicInvoiceModel] Parsing flags...');
      final isObsolete = json['isObsolete'] ?? json['is_obsolete'] ?? false;
      final paidOnDate = json['paidOnDate'] ?? json['paid_on_date'];

      print('🔵 [PublicInvoiceModel] Parsing claimed_invoices...');
      List<ClaimedInvoice>? claimedInvoices;
      if (json['claimed_invoices'] != null) {
        print(
            '🔵 [PublicInvoiceModel] Found ${(json['claimed_invoices'] as List).length} claimed invoices');
        claimedInvoices = (json['claimed_invoices'] as List).map((e) {
          print(
              '🔵 [PublicInvoiceModel] Parsing claimed invoice: ${e['digital_invoice_id']}');
          return ClaimedInvoice.fromJson(e);
        }).toList();
      }

      print('🔵 [PublicInvoiceModel] Creating object...');
      return PublicInvoiceModel(
        id: id,
        publicToken: publicToken,
        amount: amount,
        description: description,
        category: category,
        status: status,
        deadline: deadline,
        senderIban: senderIban,
        senderName: senderName,
        referenceNo: referenceNo,
        originalInvoiceNo: originalInvoiceNo,
        senderPrivateUserId: senderPrivateUserId,
        receiverPrivateUserId: receiverPrivateUserId,
        viewCount: viewCount,
        claimCount: claimCount,
        data: data,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isObsolete: isObsolete,
        paidOnDate: paidOnDate,
        claimedInvoices: claimedInvoices,
      );
    } catch (e, stackTrace) {
      print('🔴 [PublicInvoiceModel] ERROR: $e');
      print('🔴 [PublicInvoiceModel] Stack: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'publicToken': publicToken,
      'amount': amount,
      'description': description,
      'category': category,
      'status': status,
      'deadline': deadline,
      'senderIban': senderIban,
      'senderName': senderName,
      'referenceNo': referenceNo,
      'originalInvoiceNo': originalInvoiceNo,
      'senderPrivateUserId': senderPrivateUserId,
      'receiverPrivateUserId': receiverPrivateUserId,
      'viewCount': viewCount,
      'claimCount': claimCount,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isObsolete': isObsolete,
      'paidOnDate': paidOnDate,
    };
  }
}

class ClaimedInvoice {
  final int? digitalInvoiceId;
  final int? claimedByUserId;
  final String? createdAt;
  final InvoiceModel? digitalInvoices;

  ClaimedInvoice({
    this.digitalInvoiceId,
    this.claimedByUserId,
    this.createdAt,
    this.digitalInvoices,
  });

  factory ClaimedInvoice.fromJson(Map<String, dynamic> json) {
    print('🟡 [ClaimedInvoice] Starting parse...');
    print('🟡 [ClaimedInvoice] JSON keys: ${json.keys}');

    try {
      print(
          '🟡 [ClaimedInvoice] Parsing digital_invoice_id: ${json['digital_invoice_id']}');
      final digitalInvoiceId = json['digital_invoice_id'];

      print(
          '🟡 [ClaimedInvoice] Parsing claimed_by_user_id: ${json['claimed_by_user_id']}');
      final claimedByUserId = json['claimed_by_user_id'];

      print('🟡 [ClaimedInvoice] Parsing created_at: ${json['created_at']}');
      final createdAt = json['created_at'];

      print('🟡 [ClaimedInvoice] Checking for digital_invoices...');
      InvoiceModel? digitalInvoices;
      if (json['digital_invoices'] != null) {
        print(
            '🟡 [ClaimedInvoice] Found digital_invoices, parsing InvoiceModel...');
        digitalInvoices = InvoiceModel.fromJson(json['digital_invoices']);
        print('🟡 [ClaimedInvoice] InvoiceModel parsed successfully');
      }

      print('🟡 [ClaimedInvoice] Creating object...');
      return ClaimedInvoice(
        digitalInvoiceId: digitalInvoiceId,
        claimedByUserId: claimedByUserId,
        createdAt: createdAt,
        digitalInvoices: digitalInvoices,
      );
    } catch (e, stackTrace) {
      print('🔴 [ClaimedInvoice] ERROR: $e');
      print('🔴 [ClaimedInvoice] Stack: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'digital_invoice_id': digitalInvoiceId,
      'claimed_by_user_id': claimedByUserId,
      'created_at': createdAt,
      'digital_invoices': digitalInvoices?.toJson(),
    };
  }
}
