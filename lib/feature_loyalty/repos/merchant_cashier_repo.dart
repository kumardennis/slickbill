import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/merchant_check_in_session_model.dart';
import '../models/merchant_session_bill_result_model.dart';
import '../models/merchant_session_group_bill_result_model.dart';
import '../utils/loyalty_error_message.dart';

class MerchantCashierRepo {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<MerchantCheckInSessionModel>> listOpenSessions() async {
    try {
      final response = await _client.rpc('merchant_list_open_sessions');
      final rows = _coerceRpcJsonList(response);
      if (rows == null) return const [];

      return rows
          .whereType<Map>()
          .map((row) => MerchantCheckInSessionModel.fromJson(
                Map<String, dynamic>.from(row),
              ))
          .toList();
    } catch (e, st) {
      debugPrint('merchant_list_open_sessions failed: $e\n$st');
      throw loyaltyErrorMessage(e);
    }
  }

  /// PostgREST may return json arrays as List, String, or nested dynamic values.
  List<dynamic>? _coerceRpcJsonList(dynamic response) {
    if (response == null) return const [];
    if (response is List) return response;
    if (response is String && response.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(response);
        if (decoded is List) return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> closeCheckInSession(int sessionId) async {
    try {
      await _client.rpc(
        'merchant_close_check_in_session',
        params: {'p_session_id': sessionId},
      );
    } catch (e, st) {
      debugPrint('merchant_close_check_in_session failed: $e\n$st');
      throw loyaltyErrorMessage(e);
    }
  }

  Future<MerchantSessionBillResultModel> createInvoiceForSession({
    required int sessionId,
    required String memberToken,
    required double amount,
    String? description,
  }) async {
    try {
      final response = await _client.rpc(
        'merchant_create_invoice_for_session',
        params: {
          'p_session_id': sessionId,
          'p_member_token': memberToken.trim(),
          'p_amount': amount,
          if (description != null && description.trim().isNotEmpty)
            'p_description': description.trim(),
        },
      );
      if (response is Map<String, dynamic>) {
        return MerchantSessionBillResultModel.fromJson(response);
      }
      throw StateError('Invalid bill response');
    } catch (e, st) {
      debugPrint('merchant_create_invoice_for_session failed: $e\n$st');
      if (e is String) rethrow;
      throw loyaltyErrorMessage(e);
    }
  }

  Future<MerchantSessionGroupBillResultModel> createGroupInvoiceForSession({
    required int sessionId,
    required List<Map<String, dynamic>> splits,
    String? description,
  }) async {
    try {
      final response = await _client.rpc(
        'merchant_create_group_invoice_for_session',
        params: {
          'p_session_id': sessionId,
          'p_splits': splits,
          if (description != null && description.trim().isNotEmpty)
            'p_description': description.trim(),
        },
      );
      if (response is Map<String, dynamic>) {
        return MerchantSessionGroupBillResultModel.fromJson(response);
      }
      throw StateError('Invalid group bill response');
    } catch (e, st) {
      debugPrint('merchant_create_group_invoice_for_session failed: $e\n$st');
      if (e is String) rethrow;
      throw loyaltyErrorMessage(e);
    }
  }

  /// Bills session members. One positive amount → private invoice; two or more → group invoice.
  Future<void> billSessionMembers({
    required int sessionId,
    required Map<String, double> amountsByMemberToken,
  }) async {
    final splits = amountsByMemberToken.entries
        .where((entry) => entry.value > 0)
        .map(
          (entry) => {
            'member_token': entry.key,
            'amount': double.parse(entry.value.toStringAsFixed(2)),
          },
        )
        .toList();

    if (splits.isEmpty) return;

    if (splits.length == 1) {
      final split = splits.first;
      await createInvoiceForSession(
        sessionId: sessionId,
        memberToken: split['member_token'] as String,
        amount: (split['amount'] as num).toDouble(),
      );
      return;
    }

    await createGroupInvoiceForSession(
      sessionId: sessionId,
      splits: splits,
    );
  }
}
