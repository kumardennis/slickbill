import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_active_visit_model.dart';
import '../models/merchant_check_in_result_model.dart';
import '../utils/loyalty_error_message.dart';

class CustomerCheckInRepo {
  final SupabaseClient _client = Supabase.instance.client;

  Future<MerchantCheckInResultModel> checkIn({
    required String checkoutToken,
    String? joinCode,
  }) async {
    try {
      final response = await _client.rpc(
        'merchant_check_in',
        params: {
          'p_checkout_token': checkoutToken.trim(),
          // Always pass p_join_code so PostgREST resolves the 3d overload
          // (the legacy 1-arg function references dropped columns).
          'p_join_code': joinCode != null && joinCode.trim().isNotEmpty
              ? joinCode.trim()
              : null,
        },
      );
      if (response is Map<String, dynamic>) {
        return MerchantCheckInResultModel.fromJson(response);
      }
      throw StateError('Invalid check-in response');
    } catch (e, st) {
      debugPrint('merchant_check_in failed: $e\n$st');
      if (e is String) rethrow;
      throw loyaltyErrorMessage(e);
    }
  }

  Future<CustomerActiveVisitModel?> getActiveVisit() async {
    try {
      final response = await _client.rpc('customer_get_active_visit');
      if (response == null) return null;
      if (response is Map<String, dynamic>) {
        final sessionId =
            (response['sessionId'] ?? response['session_id'] as num?)?.toInt();
        if (sessionId == null || sessionId <= 0) {
          return null;
        }
        return CustomerActiveVisitModel.fromJson(response);
      }
      return null;
    } catch (e, st) {
      debugPrint('customer_get_active_visit failed: $e\n$st');
      throw loyaltyErrorMessage(e);
    }
  }
}
