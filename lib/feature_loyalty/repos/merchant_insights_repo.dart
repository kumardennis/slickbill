import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/merchant_checkout_qr_model.dart';
import '../models/merchant_customer_link_model.dart';
import '../models/merchant_dashboard_model.dart';
import '../utils/loyalty_error_message.dart';

class MerchantInsightsRepo {
  final SupabaseClient _client = Supabase.instance.client;

  Future<MerchantDashboardModel> getDashboard() async {
    try {
      final response = await _client.rpc('merchant_get_dashboard');
      if (response is Map<String, dynamic>) {
        return MerchantDashboardModel.fromJson(response);
      }
      return MerchantDashboardModel.empty;
    } catch (e, st) {
      debugPrint('merchant_get_dashboard failed: $e\n$st');
      throw loyaltyErrorMessage(e);
    }
  }

  Future<List<MerchantCustomerLinkModel>> listCustomers({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'merchant_list_customers',
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (response is! List) return const [];

      return response
          .whereType<Map>()
          .map((row) => MerchantCustomerLinkModel.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList();
    } catch (e, st) {
      debugPrint('merchant_list_customers failed: $e\n$st');
      throw loyaltyErrorMessage(e);
    }
  }

  Future<MerchantCheckoutQrModel> getCheckoutQr() async {
    try {
      final response = await _client.rpc('merchant_get_checkout_qr');
      if (response is Map<String, dynamic>) {
        return MerchantCheckoutQrModel.fromJson(response);
      }
      throw StateError('Invalid checkout QR response');
    } catch (e, st) {
      debugPrint('merchant_get_checkout_qr failed: $e\n$st');
      throw loyaltyErrorMessage(e);
    }
  }
}
