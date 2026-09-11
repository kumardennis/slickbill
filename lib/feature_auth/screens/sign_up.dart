import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:slickbill/feature_auth/widgets/auth_page_scaffold.dart';
import 'package:slickbill/feature_auth/widgets/continue_with_google_button.dart';

class SignUp extends HookWidget {
  SignUp({Key? key}) : super(key: key);

  final _supabase = SupabaseAuthManger();

  @override
  Widget build(BuildContext context) {
    TextEditingController? email = useTextEditingController();
    TextEditingController? fullName = useTextEditingController();
    TextEditingController? password = useTextEditingController();
    TextEditingController? confirmPassword = useTextEditingController();

    final isLoading = useState<bool>(false); // ✅ Add loading state

    void signUp() async {
      // ✅ Add email validation
      if (email.text.isEmpty || !email.text.contains('@')) {
        Get.snackbar('Oops..', 'Please enter a valid email');
        return;
      }

      final trimmedName = fullName.text.trim();
      if (trimmedName.isEmpty) {
        Get.snackbar('Oops..', 'Please enter your name');
        return;
      }

      if (password.text.isEmpty || password.text.length < 6) {
        Get.snackbar('Oops..', 'Password must be at least 6 characters');
        return;
      }

      if (password.text != confirmPassword.text) {
        Get.snackbar('Oops..', 'Passwords not matching');
        return;
      }

      // ✅ Show loading state
      isLoading.value = true;

      try {
        print('🔄 Starting signup for: ${email.text}'); // ✅ Debug log

        final nameParts =
            trimmedName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
        final firstName = nameParts.isNotEmpty ? nameParts.first : trimmedName;
        final lastName =
            nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        final suggestedUsername = email.text.trim().contains('@')
            ? email.text.trim().split('@').first
            : email.text.trim();

        await _supabase.signUp(
          email.text,
          password.text,
          suggestedUsername,
          firstName: firstName,
          lastName: lastName,
        );

        print('✅ Signup successful'); // ✅ Debug log

        // ✅ Show success message
        Get.snackbar(
          'Success',
          'Account created! Please check your email to verify.',
          backgroundColor: Colors.green.withOpacity(0.1),
          colorText: Colors.green,
          duration: Duration(seconds: 3),
        );
      } catch (e) {
        print('❌ Signup error: $e'); // ✅ Debug log

        Get.snackbar(
          'Error',
          'Failed to create account: ${e.toString()}',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      } finally {
        isLoading.value = false; // ✅ Hide loading state
      }
    }

    return AuthPageScaffold(
      title: 'lbl_AuthSignUpTitle'.tr,
      subtitle: 'lbl_AuthSubtitle'.tr,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ContinueWithGoogleButton(),
            const SizedBox(height: 20),
            const AuthOrDivider(),
            const SizedBox(height: 20),
            AuthTextField(
              controller: fullName,
              label: 'lbl_FullName'.tr,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: email,
              label: 'lbl_Email'.tr,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: password,
              label: 'lbl_Password'.tr,
              obscure: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: confirmPassword,
              label: 'lbl_ConfirmPassword'.tr,
              obscure: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              autocorrect: false,
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'btn_SignUp'.tr,
              onPressed: signUp,
              isLoading: isLoading.value,
            ),
            const SizedBox(height: 16),
            AuthFooterLink(
              prompt: 'lbl_AuthHasAccount'.tr,
              action: 'lbl_AuthSignInAction'.tr,
              onTap: () => Get.toNamed('/sign-in'),
            ),
          ],
        ),
      ),
    );
  }
}
