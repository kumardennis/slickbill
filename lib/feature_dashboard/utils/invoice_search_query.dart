import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/invoice_list_query.dart';
import '../models/invoice_model.dart';

enum InvoiceSearchSide { received, sent }

/// RPC search is a separate state from the invoices Edge folder list.
class InvoiceSearchQuery {
  static const _idChunk = 100;

  static String _select(InvoiceSearchSide side) {
    switch (side) {
      case InvoiceSearchSide.received:
        return '*, senders(*, private_users(*, users(*))), receivers!inner(*, private_users(*, users(*)), business_users(*))';
      case InvoiceSearchSide.sent:
        return '*, senders!inner(*, private_users(*, users(*))), receivers(*, private_users(*, users(*)), business_users(*))';
    }
  }

  static Future<List<InvoiceModel>> search({
    required InvoiceSearchSide side,
    required InvoiceListQuery query,
    required int privateUserId,
  }) async {
    final q = query.sanitizedSearch;
    if (q.isEmpty) return const [];

    final client = Supabase.instance.client;
    final raw = await client.rpc(
      'search_my_digital_invoice_ids',
      params: {
        'p_side': side == InvoiceSearchSide.received ? 'received' : 'sent',
        'p_q': q,
      },
    );

    final ids = <int>[];
    if (raw is List) {
      for (final row in raw) {
        if (row is Map && row['id'] is num) {
          ids.add((row['id'] as num).toInt());
        } else if (row is num) {
          ids.add(row.toInt());
        }
      }
    }
    if (ids.isEmpty) return const [];

    final rows = <InvoiceModel>[];
    for (var i = 0; i < ids.length; i += _idChunk) {
      final chunk = ids.sublist(i, min(i + _idChunk, ids.length));
      var request = client
          .from('digital_invoices')
          .select(_select(side))
          .inFilter('id', chunk)
          .eq('isObsolete', false);

      request = side == InvoiceSearchSide.received
          ? request.eq('receivers.privateUserId', privateUserId)
          : request.eq('senders.privateUserId', privateUserId);

      final data = await request.order('created_at', ascending: false);
      rows.addAll(
        (data as List).map((e) => InvoiceModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            )),
      );
    }

    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows.where((invoice) {
      return query.matches(
        status: invoice.status,
        createdAt: invoice.createdAt,
        paidOnDate: invoice.paidOnDate,
        deadline: invoice.deadline,
      );
    }).toList();
  }
}
