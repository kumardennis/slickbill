import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_loyalty/models/customer_active_visit_model.dart';
import 'package:slickbill/feature_loyalty/repos/customer_check_in_repo.dart';
import 'package:slickbill/feature_loyalty/widgets/customer_visit_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks the customer's active OPEN visit for app bar + join QR.
class CustomerActiveVisitController extends GetxController {
  final CustomerCheckInRepo _repo = CustomerCheckInRepo();

  final activeVisit = Rxn<CustomerActiveVisitModel>();

  RealtimeChannel? _channel;
  String? _customerPrivateUserId;

  void attach({required String customerPrivateUserId}) {
    if (customerPrivateUserId.isEmpty) {
      detach();
      return;
    }
    if (_customerPrivateUserId == customerPrivateUserId && _channel != null) {
      return;
    }

    detach();
    _customerPrivateUserId = customerPrivateUserId;

    unawaited(refresh());

    try {
      _channel = Supabase.instance.client
          .channel('customer-visit-$customerPrivateUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'customer_visit_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'customer_private_user_id',
              value: customerPrivateUserId,
            ),
            callback: (payload) {
              unawaited(_onVisitEvent(payload.newRecord));
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[CustomerActiveVisit] subscribe failed: $e');
    }
  }

  void detach() {
    final channel = _channel;
    _channel = null;
    _customerPrivateUserId = null;
    activeVisit.value = null;
    if (channel == null) return;
    Supabase.instance.client.removeChannel(channel).catchError((_) => '');
  }

  Future<void> refresh() async {
    if (_customerPrivateUserId == null) return;
    try {
      activeVisit.value = await _repo.getActiveVisit();
    } catch (e) {
      debugPrint('[CustomerActiveVisit] refresh failed: $e');
    }
  }

  Future<void> _onVisitEvent(Map<String, dynamic> record) async {
    final eventType = (record['event_type'] as String?)?.trim();
    if (eventType != 'session_closed') return;

    final sessionId = (record['session_id'] as num?)?.toInt();
    final current = activeVisit.value;
    if (current != null &&
        sessionId != null &&
        current.sessionId == sessionId) {
      activeVisit.value = null;
      return;
    }

    await refresh();
  }

  void applyVisit(CustomerActiveVisitModel visit) {
    activeVisit.value = visit;
  }

  Future<void> showVisitSheet() async {
    final visit = activeVisit.value;
    if (visit == null) return;
    await showCustomerVisitBottomSheet(visit: visit);
    await refresh();
  }
}
