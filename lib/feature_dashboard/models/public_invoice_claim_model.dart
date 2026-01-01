class PublicInvoiceClaimModel {
  final int id;
  final int publicInvoiceId;
  final int claimedByUserId;
  final DateTime createdAt;
  final int? digitalInvoiceId;

  PublicInvoiceClaimModel({
    required this.id,
    required this.publicInvoiceId,
    required this.claimedByUserId,
    required this.createdAt,
    this.digitalInvoiceId,
  });

  factory PublicInvoiceClaimModel.fromJson(Map<String, dynamic> json) {
    return PublicInvoiceClaimModel(
      id: json['id'] as int,
      publicInvoiceId: json['public_invoice_id'] as int,
      claimedByUserId: json['claimed_by_user_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      digitalInvoiceId: json['digital_invoice_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'public_invoice_id': publicInvoiceId,
      'claimed_by_user_id': claimedByUserId,
      'created_at': createdAt.toIso8601String(),
      'digital_invoice_id': digitalInvoiceId,
    };
  }

  PublicInvoiceClaimModel copyWith({
    int? id,
    int? publicInvoiceId,
    int? claimedByUserId,
    DateTime? createdAt,
    int? digitalInvoiceId,
  }) {
    return PublicInvoiceClaimModel(
      id: id ?? this.id,
      publicInvoiceId: publicInvoiceId ?? this.publicInvoiceId,
      claimedByUserId: claimedByUserId ?? this.claimedByUserId,
      createdAt: createdAt ?? this.createdAt,
      digitalInvoiceId: digitalInvoiceId ?? this.digitalInvoiceId,
    );
  }

  @override
  String toString() {
    return 'PublicInvoiceClaimModel(id: $id, publicInvoiceId: $publicInvoiceId, '
        'claimedByUserId: $claimedByUserId, createdAt: $createdAt, '
        'digitalInvoiceId: $digitalInvoiceId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicInvoiceClaimModel &&
        other.id == id &&
        other.publicInvoiceId == publicInvoiceId &&
        other.claimedByUserId == claimedByUserId &&
        other.createdAt == createdAt &&
        other.digitalInvoiceId == digitalInvoiceId;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      publicInvoiceId.hashCode ^
      claimedByUserId.hashCode ^
      createdAt.hashCode ^
      digitalInvoiceId.hashCode;
}
