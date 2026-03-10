import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserRepo {
  final SupabaseClient _client = Supabase.instance.client;

  /// Update CDP Wallet ID for a user
  Future<Map<String, dynamic>?> updateCdpWalletId({
    required int userId,
    required String cdpWalletId,
    required String cdpUserId,
  }) async {
    try {
      final response = await _client
          .from('users')
          .update({
            'cdpWalletId': cdpWalletId,
            'cdpUserId': cdpUserId,
          })
          .eq('id', userId)
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('❌ Error updating CDP wallet ID: $e');
      rethrow;
    }
  }

  /// Get user's CDP Wallet ID
  Future<String?> getCdpWalletId(int userId) async {
    try {
      final response = await _client
          .from('users')
          .select('cdpWalletId')
          .eq('id', userId)
          .single();

      return response['cdpWalletId'] as String?;
    } catch (e) {
      debugPrint('❌ Error fetching CDP wallet ID: $e');
      return null;
    }
  }
}
