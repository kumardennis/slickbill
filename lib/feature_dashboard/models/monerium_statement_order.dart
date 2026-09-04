class MoneriumStatementOrder {
  final String id;
  final String kind;
  final String state;
  final double amount;
  final String currency;
  final String? memo;
  final String? counterpartName;
  final String? counterpartIban;
  final DateTime? placedAt;
  final String? txHash;
  final String? chain;

  const MoneriumStatementOrder({
    required this.id,
    required this.kind,
    required this.state,
    required this.amount,
    required this.currency,
    this.memo,
    this.counterpartName,
    this.counterpartIban,
    this.placedAt,
    this.txHash,
    this.chain,
  });

  bool get isIncoming => kind.toLowerCase() == 'issue';
  bool get isOutgoing => kind.toLowerCase() == 'redeem';
  bool get isProcessed => state.toLowerCase() == 'processed';
  bool get isRejected => state.toLowerCase() == 'rejected';
  bool get isPending => !isProcessed && !isRejected;

  factory MoneriumStatementOrder.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map<String, dynamic>
        ? json['meta'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final counterpart = json['counterpart'] is Map<String, dynamic>
        ? json['counterpart'] as Map<String, dynamic>
        : null;
    final identifier = counterpart?['identifier'] is Map<String, dynamic>
        ? counterpart!['identifier'] as Map<String, dynamic>
        : null;
    final details = counterpart?['details'] is Map<String, dynamic>
        ? counterpart!['details'] as Map<String, dynamic>
        : null;

    return MoneriumStatementOrder(
      id: (json['id'] ?? json['orderId'] ?? json['uuid'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      currency: (json['currency'] ?? 'eur').toString().toUpperCase(),
      memo: _firstString([
        json['memo'],
        meta['memo'],
        json['comment'],
        json['narrative'],
      ]),
      counterpartName: _counterpartName(details),
      counterpartIban: identifier?['iban']?.toString(),
      placedAt: _parseDate(
        meta['placedAt'] ??
            meta['processedAt'] ??
            json['placedAt'] ??
            json['createdAt'] ??
            json['created_at'],
      ),
      txHash: _firstTxHash(json, meta),
      chain: (json['chain'] ?? meta['chain'])?.toString(),
    );
  }

  static String? _firstString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static String? _counterpartName(Map<String, dynamic>? details) {
    if (details == null) return null;
    final company = details['companyName']?.toString().trim();
    if (company != null && company.isNotEmpty) return company;
    final name = details['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final first = details['firstName']?.toString().trim() ?? '';
    final last = details['lastName']?.toString().trim() ?? '';
    final combined = '$first $last'.trim();
    return combined.isEmpty ? null : combined;
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      final ms = raw > 9999999999 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  static String? _firstTxHash(
    Map<String, dynamic> json,
    Map<String, dynamic> meta,
  ) {
    final top = json['txHash']?.toString().trim();
    if (top != null && top.isNotEmpty) return top;

    final hashes = meta['txHashes'] ?? json['txHashes'];
    if (hashes is List && hashes.isNotEmpty) {
      final first = hashes.first?.toString().trim();
      if (first != null && first.isNotEmpty) return first;
    }
    return null;
  }
}
