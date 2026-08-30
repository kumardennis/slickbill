import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_merchant_relationship_model.dart';

class CustomerRelationshipsRepo {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<CustomerMerchantRelationshipModel>> listMerchantRelationships({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'customer_list_merchant_relationships',
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (response is! List) return const [];

      return response
          .whereType<Map>()
          .map((row) => CustomerMerchantRelationshipModel.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList();
    } catch (e, st) {
      debugPrint('customer_list_merchant_relationships failed: $e\n$st');
      rethrow;
    }
  }
}
