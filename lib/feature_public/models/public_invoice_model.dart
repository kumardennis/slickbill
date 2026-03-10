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

  // ✅ these match your Supabase select aliases
  final PrivateUsers? sender;
  final int? receiverPrivateUserId;
  final PrivateUsers? receiver;

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
    this.sender,
    this.receiverPrivateUserId,
    this.receiver,
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
    final id = json['id'] as int;

    final publicToken =
        (json['publicToken'] ?? json['public_token']) as String?;
    final amount = (json['amount'] ?? 0).toDouble();

    final description = json['description'] as String?;
    final category = json['category'] as String?;
    final status = (json['status'] ?? 'UNPAID') as String;
    final deadline = json['deadline'] as String?;

    final senderIban = json['senderIban'] ?? json['sender_iban'];
    final senderName = json['senderName'] ?? json['sender_name'];
    final referenceNo = json['referenceNo'] ?? json['reference_no'];
    final originalInvoiceNo =
        json['originalInvoiceNo'] ?? json['original_invoice_no'];

    final senderPrivateUserId =
        json['senderPrivateUserId'] ?? json['sender_private_user_id'];
    final receiverPrivateUserId =
        json['receiverPrivateUserId'] ?? json['receiver_private_user_id'];

    final viewCount = json['viewCount'] ?? json['view_count'] ?? 0;
    final claimCount = json['claimCount'] ?? json['claim_count'] ?? 0;

    final data = json['data'];

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

    final isObsolete = json['isObsolete'] ?? json['is_obsolete'] ?? false;
    final paidOnDate = json['paidOnDate'] ?? json['paid_on_date'];

    // ✅ parse sender/receiver objects returned by the query aliases
    final senderJson = json['sender'];
    final receiverJson = json['receiver'];

    final sender = senderJson is Map<String, dynamic>
        ? PrivateUsers.fromJson(senderJson)
        : null;

    final receiver = receiverJson is Map<String, dynamic>
        ? PrivateUsers.fromJson(receiverJson)
        : null;

    // (optional) claimed invoices if you ever select them
    List<ClaimedInvoice>? claimedInvoices;
    if (json['claimed_invoices'] is List) {
      claimedInvoices = (json['claimed_invoices'] as List)
          .whereType<Map<String, dynamic>>()
          .map(ClaimedInvoice.fromJson)
          .toList();
    }

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
      sender: sender,
      receiverPrivateUserId: receiverPrivateUserId,
      receiver: receiver,
      viewCount: viewCount,
      claimCount: claimCount,
      data: data,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isObsolete: isObsolete,
      paidOnDate: paidOnDate,
      claimedInvoices: claimedInvoices,
    );
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
      // include joined objects if you want
      'sender': sender?.toJson(),
      'receiver': receiver?.toJson(),
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
