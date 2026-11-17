import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:slickbill/feature_auth/widgets/auth_page_scaffold.dart';

class ForgotPassword extends HookWidget {
  const ForgotPassword({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = useTextEditingController();
    final isSending = useState(false);
    final auth = useMemoized(SupabaseAuthManger.new);

    Future<void> sendReset() async {
      final email = emailController.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        Get.snackbar(
          'Email required',
          'Enter the email on your account.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }

      isSending.value = true;
      try {
        await auth.sendPasswordResetEmail(email);
        Get.snackbar(
          'Check your inbox',
          'If that email has a SlickBills account, we sent a link to set a password. Google accounts can use this too.',
          backgroundColor: Colors.green.withOpacity(0.15),
          colorText: Colors.green.shade800,
          duration: const Duration(seconds: 5),
        );
      } catch (e) {
        Get.snackbar(
          'Could not send',
          e.toString(),
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
      } finally {
        isSending.value = false;
      }
    }

    return AuthPageScaffold(
      title: 'lbl_ForgotPasswordTitle'.tr,
      subtitle: 'lbl_ForgotPasswordSubtitle'.tr,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: emailController,
              label: 'lbl_Email'.tr,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'btn_SendResetLink'.tr,
              onPressed: sendReset,
              isLoading: isSending.value,
            ),
            const SizedBox(height: 16),
            AuthFooterLink(
              prompt: 'lbl_AuthHasAccount'.tr,
              action: 'lbl_AuthSignInAction'.tr,
              onTap: () => Get.offAllNamed('/sign-in'),
            ),
          ],
        ),
      ),
    );
  }
}
