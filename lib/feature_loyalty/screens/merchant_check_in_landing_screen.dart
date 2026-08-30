import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/screens/sign_in.dart';
import 'package:slickbill/feature_loyalty/getx_controllers/customer_active_visit_controller.dart';
import 'package:slickbill/feature_loyalty/models/customer_active_visit_model.dart';
import 'package:slickbill/feature_loyalty/models/merchant_check_in_result_model.dart';
import 'package:slickbill/feature_loyalty/repos/customer_check_in_repo.dart';
import 'package:slickbill/feature_loyalty/widgets/customer_visit_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantCheckInLandingScreen extends HookWidget {
  final String checkoutToken;
  final String? joinCode;

  const MerchantCheckInLandingScreen({
    super.key,
    required this.checkoutToken,
    this.joinCode,
  });

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => CustomerCheckInRepo());
    final result = useState<MerchantCheckInResultModel?>(null);
    final isLoading = useState(true);
    final error = useState<String?>(null);
    final colors = Theme.of(context).colorScheme;

    Future<void> runCheckIn() async {
      isLoading.value = true;
      error.value = null;
      try {
        result.value = await repo.checkIn(
          checkoutToken: checkoutToken,
          joinCode: joinCode,
        );
      } catch (e) {
        error.value = e is String ? e : e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        isLoading.value = false;
        return null;
      }
      runCheckIn();
      return null;
    }, [checkoutToken, joinCode]);

    useEffect(() {
      final checkInResult = result.value;
      if (checkInResult == null || !context.mounted) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;

        final visit = CustomerActiveVisitModel(
          sessionId: checkInResult.sessionId,
          sessionToken: checkInResult.sessionToken,
          memberToken: checkInResult.memberToken,
          joinCode: checkInResult.joinCode,
          joinUrl: checkInResult.joinUrl,
          merchantPublicName: checkInResult.merchantPublicName,
          loyaltyBadge: checkInResult.loyaltyBadge,
          memberCount: checkInResult.memberCount,
        );

        if (Get.isRegistered<CustomerActiveVisitController>()) {
          Get.find<CustomerActiveVisitController>().applyVisit(visit);
        }

        await showCustomerVisitBottomSheet(visit: visit);
        if (context.mounted) {
          Get.back();
        }
      });
      return null;
    }, [result.value]);

    return Scaffold(
      backgroundColor: colors.light,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.close, color: colors.dark),
                ),
              ),
              const Spacer(),
              if (Supabase.instance.client.auth.currentSession == null) ...[
                Icon(Icons.login, size: 48, color: colors.blue),
                const SizedBox(height: 16),
                Text(
                  'lbl_CheckInSignInRequired'.tr,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.dark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await Get.to(() => const SignIn());
                    if (Supabase.instance.client.auth.currentSession != null) {
                      await runCheckIn();
                    }
                  },
                  child: Text('btn_SignIn'.tr),
                ),
              ] else if (isLoading.value)
                const Center(child: CircularProgressIndicator())
              else if (error.value != null) ...[
                Icon(Icons.error_outline, size: 48, color: colors.red),
                const SizedBox(height: 16),
                Text(
                  error.value!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: runCheckIn,
                  child: Text('btn_Retry'.tr),
                ),
              ] else if (result.value != null)
                const Center(child: CircularProgressIndicator()),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
