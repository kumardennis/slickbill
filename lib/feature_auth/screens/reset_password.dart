import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/app_lock_controller.dart';
import 'package:slickbill/feature_auth/utils/auth_callback_uri.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:slickbill/feature_auth/widgets/auth_page_scaffold.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPassword extends HookWidget {
  const ResetPassword({super.key});

  @override
  Widget build(BuildContext context) {
    final passwordController = useTextEditingController();
    final confirmController = useTextEditingController();
    final isSaving = useState(false);
    final isReady = useState(Supabase.instance.client.auth.currentSession != null);
    final linkError = useState<String?>(null);
    final fromProfile = Get.arguments is Map &&
        (Get.arguments as Map)['fromProfile'] == true;
    final auth = useMemoized(SupabaseAuthManger.new);

    useEffect(() {
      var cancelled = false;

      Future<void> completeRecoverySession() async {
        if (fromProfile) {
          isReady.value = true;
          return;
        }

        if (kIsWeb) {
          final uri = Uri.base;
          final params = AuthCallbackUri.params(uri);
          final hasCode = params.containsKey('code') ||
              params.containsKey('access_token');
          if (hasCode) {
            try {
              await Supabase.instance.client.auth.getSessionFromUrl(uri);
            } catch (error) {
              debugPrint('Password recovery exchange: $error');
            }
          }
        }

        if (cancelled) return;

        if (Supabase.instance.client.auth.currentSession != null) {
          AuthCallbackUri.passwordRecoveryPending = true;
          isReady.value = true;
          return;
        }

        await Future.delayed(const Duration(milliseconds: 800));
        if (cancelled) return;

        if (Supabase.instance.client.auth.currentSession != null) {
          AuthCallbackUri.passwordRecoveryPending = true;
          isReady.value = true;
          return;
        }

        linkError.value =
            'This reset link is invalid or expired. Request a new one.';
      }

      final sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (cancelled) return;
        if (data.event == AuthChangeEvent.passwordRecovery ||
            (data.event == AuthChangeEvent.signedIn && data.session != null)) {
          isReady.value = true;
          linkError.value = null;
        }
      });

      unawaited(completeRecoverySession());

      return () {
        cancelled = true;
        sub.cancel();
      };
    }, const []);

    Future<void> savePassword() async {
      final password = passwordController.text;
      final confirm = confirmController.text;

      if (password.length < 6) {
        Get.snackbar(
          'Oops..',
          'Password must be at least 6 characters',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }
      if (password != confirm) {
        Get.snackbar(
          'Oops..',
          'Passwords not matching',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }

      isSaving.value = true;
      try {
        await auth.updatePassword(password);
        AuthCallbackUri.passwordRecoveryPending = false;

        Get.snackbar(
          'Password saved',
          'You can now sign in with email and password, or keep using Google.',
          backgroundColor: Colors.green.withOpacity(0.15),
          colorText: Colors.green.shade800,
          duration: const Duration(seconds: 4),
        );

        if (fromProfile) {
          Get.back();
          return;
        }

        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          AppLockController.markInteractiveLogin();
          final loaded = await auth.loadFreshUser(
            session.user.id,
            session.accessToken,
          );
          if (loaded) {
            Get.offAllNamed('/home-screen');
            return;
          }
        }
        Get.offAllNamed('/sign-in');
      } catch (e) {
        Get.snackbar(
          'Could not save password',
          e.toString(),
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
      } finally {
        isSaving.value = false;
      }
    }

    final waiting = !isReady.value && linkError.value == null;

    return AuthPageScaffold(
      title: fromProfile
          ? 'lbl_SetPasswordTitle'.tr
          : 'lbl_ResetPasswordTitle'.tr,
      subtitle: 'lbl_ResetPasswordSubtitle'.tr,
      isLoading: waiting,
      child: linkError.value != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  linkError.value!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: 'btn_SendResetLink'.tr,
                  onPressed: () => Get.offAllNamed('/forgot-password'),
                ),
                const SizedBox(height: 16),
                AuthFooterLink(
                  prompt: 'lbl_AuthHasAccount'.tr,
                  action: 'lbl_AuthSignInAction'.tr,
                  onTap: () => Get.offAllNamed('/sign-in'),
                ),
              ],
            )
          : AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    controller: passwordController,
                    label: 'lbl_Password'.tr,
                    obscure: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  AuthTextField(
                    controller: confirmController,
                    label: 'lbl_ConfirmPassword'.tr,
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    autocorrect: false,
                  ),
                  const SizedBox(height: 20),
                  AuthPrimaryButton(
                    label: 'btn_SavePassword'.tr,
                    onPressed: savePassword,
                    isLoading: isSaving.value,
                  ),
                ],
              ),
            ),
    );
  }
}
