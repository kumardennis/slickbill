import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rewards_ledger_entry_model.dart';
import '../models/rewards_summary_model.dart';
import '../utils/loyalty_error_message.dart';

class RewardsRepo {
  final SupabaseClient _client = Supabase.instance.client;

  Future<RewardsSummaryModel> getSummary() async {
    try {
      final response = await _client.rpc('rewards_get_summary');
      if (response is Map<String, dynamic>) {
        return RewardsSummaryModel.fromJson(response);
      }
      return RewardsSummaryModel.empty;
    } catch (e, st) {
      debugPrint('rewards_get_summary failed: $e\n$st');
      throw loyaltyErrorMessage(e);
    }
  }

  Future<List<RewardsLedgerEntryModel>> listHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'rewards_list_history',
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (response is! List) return const [];

      return response
          .whereType<Map>()
          .map((row) => RewardsLedgerEntryModel.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList();
    } catch (e, st) {
      debugPrint('rewards_list_history failed: $e\n$st');
      throw loyaltyErrorMessage(e);
    }
  }
}
