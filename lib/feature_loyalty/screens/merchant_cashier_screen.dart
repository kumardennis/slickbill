import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/models/merchant_check_in_session_model.dart';
import 'package:slickbill/feature_loyalty/getx_controllers/merchant_open_sessions_controller.dart';
import 'package:slickbill/feature_loyalty/repos/merchant_cashier_repo.dart';
import 'package:slickbill/feature_loyalty/widgets/merchant_open_session_row.dart';
import 'package:slickbill/feature_loyalty/widgets/merchant_session_bill_sheet.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

class MerchantCashierScreen extends HookWidget {
  const MerchantCashierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => MerchantCashierRepo());
    final closingId = useState<int?>(null);
    final billingId = useState<int?>(null);
    final error = useState<String?>(null);
    final isLoading = useState(true);

    final sessionsController = Get.isRegistered<MerchantOpenSessionsController>()
        ? Get.find<MerchantOpenSessionsController>()
        : null;

    Future<void> load() async {
      error.value = null;
      isLoading.value = true;
      try {
        if (sessionsController != null) {
          await sessionsController.refresh();
        }
      } catch (e) {
        error.value = e is String ? e : e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, const []);

    Future<void> billSession(MerchantCheckInSessionModel session) async {
      billingId.value = session.sessionId;
      try {
        final sent = await showMerchantSessionBillSheet(
          session: session,
          repo: repo,
        );
        if (sent) {
          await load();
        }
      } finally {
        billingId.value = null;
      }
    }

    Future<void> closeSession(int sessionId) async {
      closingId.value = sessionId;
      try {
        await repo.closeCheckInSession(sessionId);
        await load();
        if (Get.isRegistered<MerchantOpenSessionsController>()) {
          await Get.find<MerchantOpenSessionsController>().notifySessionClosed();
        }
      } catch (e) {
        Get.snackbar('Oops..', e is String ? e : e.toString());
      } finally {
        closingId.value = null;
      }
    }

    if (sessionsController == null) {
      return Scaffold(
        appBar: CustomAppbar(
          title: 'hd_MerchantCashier'.tr,
          appbarIcon: null,
          hideMerchantSessionAction: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.light,
      appBar: CustomAppbar(
        title: 'hd_MerchantCashier'.tr,
        appbarIcon: null,
        hideMerchantSessionAction: true,
      ),
      body: Obx(
        () => RefreshIndicator(
          onRefresh: load,
          child: isLoading.value && sessionsController.openSessions.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Text(
                      'lbl_MerchantCashierHint'.tr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.darkGray,
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (error.value != null) ...[
                      Text(
                        error.value!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.red,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (sessionsController.openSessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Text(
                          'lbl_NoOpenSessions'.tr,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.darkGray,
                              ),
                        ),
                      )
                    else
                      ...sessionsController.openSessions.map(
                        (session) => MerchantOpenSessionRow(
                          session: session,
                          isClosing: closingId.value == session.sessionId,
                          isBilling: billingId.value == session.sessionId,
                          onBill: () => billSession(session),
                          onClose: () => closeSession(session.sessionId),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
