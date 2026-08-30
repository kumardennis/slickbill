import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User-facing message for loyalty RPC / network failures.
String loyaltyErrorMessage(Object error) {
  if (error is PostgrestException) {
    final code = error.code?.trim();
    final message = error.message.trim();

    if (code == 'PGRST301' || message.toLowerCase().contains('jwt')) {
      return 'err_LoyaltySignInRequired'.tr;
    }
    if (message.toLowerCase().contains('business account required')) {
      return 'inf_MerchantInsightsBusinessOnly'.tr;
    }
    if (message.toLowerCase().contains('unknown checkout qr')) {
      return 'err_LoyaltyUnknownCheckoutQr'.tr;
    }
    if (message.toLowerCase().contains('cannot check in to your own')) {
      return 'err_LoyaltyOwnBusinessQr'.tr;
    }
    if (message.toLowerCase().contains('session not found')) {
      return 'err_LoyaltySessionNotFound'.tr;
    }
    if (message.toLowerCase().contains('member not found')) {
      return 'err_LoyaltyMemberNotFound'.tr;
    }
    if (message.toLowerCase().contains('amount for at least one guest') ||
        message.toLowerCase().contains('amount must be greater than zero')) {
      return 'err_LoyaltyBillAmountRequired'.tr;
    }
    if (message.toLowerCase().contains('payout iban')) {
      return 'err_LoyaltyMerchantIbanRequired'.tr;
    }
    if (message.toLowerCase().contains('group bill requires')) {
      return 'err_LoyaltyBillAmountRequired'.tr;
    }
    if (message.toLowerCase().contains('visit not found') ||
        message.toLowerCase().contains('join code')) {
      return 'err_LoyaltyVisitNotFound'.tr;
    }
    if (message.toLowerCase().contains('not authenticated')) {
      return 'err_LoyaltySignInRequired'.tr;
    }

    return 'err_LoyaltyGeneric'.tr;
  }

  return 'err_LoyaltyGeneric'.tr;
}
