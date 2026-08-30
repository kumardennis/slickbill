import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_loyalty/models/merchant_check_in_session_model.dart';
import 'package:slickbill/feature_loyalty/repos/merchant_cashier_repo.dart';
import 'package:slickbill/feature_loyalty/screens/merchant_cashier_screen.dart';
import 'package:slickbill/feature_loyalty/widgets/merchant_check_in_alert_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single owner for merchant cashier realtime, open-session state, and check-in alerts.
class MerchantOpenSessionsController extends GetxController {
  final MerchantCashierRepo _repo = MerchantCashierRepo();

  final openSessionCount = 0.obs;
  final openSessions = <MerchantCheckInSessionModel>[].obs;

  RealtimeChannel? _channel;
  String? _merchantPrivateUserId;
  int? _lastAlertSessionId;
  bool _presentingAlert = false;

  /// Visits the merchant already dismissed — don't pop the sheet again.
  final _dismissedAlertSessionIds = <int>{};

  /// Detect member joins vs re-scan bumps.
  final _memberCountBySession = <int, int>{};

  void attach({required String merchantPrivateUserId}) {
    if (merchantPrivateUserId.isEmpty) {
      detach();
      return;
    }
    if (_merchantPrivateUserId == merchantPrivateUserId && _channel != null) {
      return;
    }

    detach();
    _merchantPrivateUserId = merchantPrivateUserId;

    unawaited(refresh());

    try {
      _channel = Supabase.instance.client
          .channel('merchant-cashier-$merchantPrivateUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'merchant_cashier_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'merchant_private_user_id',
              value: merchantPrivateUserId,
            ),
            callback: (payload) {
              unawaited(_onCashierEvent(payload.newRecord));
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[MerchantOpenSessions] subscribe failed: $e');
    }
  }

  void detach() {
    final channel = _channel;
    _channel = null;
    _merchantPrivateUserId = null;
    _lastAlertSessionId = null;
    _presentingAlert = false;
    _dismissedAlertSessionIds.clear();
    _memberCountBySession.clear();
    openSessionCount.value = 0;
    openSessions.clear();
    if (channel == null) return;
    Supabase.instance.client.removeChannel(channel).catchError((_) => '');
  }

  Future<void> refresh() async {
    if (_merchantPrivateUserId == null) return;
    try {
      final sessions = await _repo.listOpenSessions();
      openSessions.assignAll(sessions);
      openSessionCount.value = sessions.length;
      for (final session in sessions) {
        _memberCountBySession[session.sessionId] = session.memberCount;
      }
    } catch (e) {
      debugPrint('[MerchantOpenSessions] refresh failed: $e');
    }
  }

  Future<void> _onCashierEvent(Map<String, dynamic> record) async {
    final eventType = (record['event_type'] as String?)?.trim();
    final sessionId = (record['session_id'] as num?)?.toInt();

    if (eventType == 'session_closed') {
      if (sessionId != null) {
        _dismissedAlertSessionIds.remove(sessionId);
        _memberCountBySession.remove(sessionId);
      }
      await refresh();
      return;
    }

    if (eventType != 'session_opened' && eventType != 'session_updated') {
      await refresh();
      return;
    }

    if (sessionId == null || sessionId <= 0) {
      await refresh();
      return;
    }

    await refresh();

    var session = _findSession(sessionId);
    if (session == null) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await refresh();
      session = _findSession(sessionId);
    }
    if (session == null) return;

    final previousMemberCount = _memberCountBySession[sessionId] ?? 0;
    _memberCountBySession[sessionId] = session.memberCount;

    if (eventType == 'session_updated') {
      if (_presentingAlert && _lastAlertSessionId == sessionId) {
        await showMerchantCheckInAlertSheet(session: session);
        return;
      }

      if (_dismissedAlertSessionIds.contains(sessionId) &&
          session.memberCount > previousMemberCount) {
        _showGuestJoinedSnackbar(session);
      }
      return;
    }

    // session_opened — new visit only (not friend joins).
    if (_dismissedAlertSessionIds.contains(sessionId)) {
      return;
    }

    if (_presentingAlert) {
      await showMerchantCheckInAlertSheet(session: session);
      _lastAlertSessionId = session.sessionId;
      return;
    }

    await _presentCheckInAlert(session);
  }

  Future<void> _presentCheckInAlert(MerchantCheckInSessionModel session) async {
    _presentingAlert = true;
    _lastAlertSessionId = session.sessionId;

    try {
      await showMerchantCheckInAlertSheet(session: session);
    } finally {
      _presentingAlert = false;
      _dismissedAlertSessionIds.add(session.sessionId);
    }
  }

  void _showGuestJoinedSnackbar(MerchantCheckInSessionModel session) {
    final token = session.sessionToken.isNotEmpty
        ? session.sessionToken
        : 'lbl_ThisUser'.tr;

    Get.snackbar(
      'inf_GuestJoinedVisit'.tr,
      'inf_GuestJoinedVisitHint'.trParams({
        'token': token,
        'count': '${session.memberCount}',
      }),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
      backgroundColor:
          Get.theme.colorScheme.surface.withValues(alpha: 0.95),
      colorText: Get.theme.colorScheme.onSurface,
      mainButton: TextButton(
        onPressed: () {
          if (Get.isSnackbarOpen) Get.closeAllSnackbars();
          openCashier();
        },
        child: Text('btn_Cashier'.tr),
      ),
    );
  }

  MerchantCheckInSessionModel? _findSession(int sessionId) {
    for (final row in openSessions) {
      if (row.sessionId == sessionId) {
        return row;
      }
    }
    return null;
  }

  void openCashier() {
    unawaited(
      Get.to(() => const MerchantCashierScreen())?.then((_) => refresh()),
    );
  }

  Future<void> notifySessionClosed() => refresh();
}
