import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:slickbill/feature_auth/widgets/continue_with_google_button.dart';
import 'package:slickbill/shared_widgets/input_field.dart';

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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.blue,
                    Theme.of(context).colorScheme.dark,
                    Theme.of(context).colorScheme.dark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // Logo
                      Container(
                        width: double.infinity,
                        height: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Image.asset('assets/logo_text_darkbg.png'),
                        ),
                      ),

                      const SizedBox(height: 40),

                      const ContinueWithGoogleButton(),

                      const SizedBox(height: 32),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).colorScheme.gray,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.gray,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Theme.of(context).colorScheme.gray,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Form Fields
                      InputField(
                        controller: fullName,
                        label: 'Full name',
                        obscure: false,
                      ),
                      InputField(
                        controller: email,
                        label: 'lbl_Email'.tr,
                        obscure: false,
                      ),
                      InputField(
                        controller: password,
                        label: 'lbl_Password'.tr,
                        obscure: true,
                      ),
                      InputField(
                        controller: confirmPassword,
                        label: 'lbl_ConfirmPassword'.tr,
                        obscure: true,
                      ),

                      const SizedBox(height: 32),

                      // Sign Up Button - Update with loading state
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading.value
                              ? null
                              : signUp, // ✅ Disable when loading
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.blue,
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading.value // ✅ Show loading indicator
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Theme.of(context).colorScheme.light,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'btn_SignUp'.tr,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.light,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign In Link
                      GestureDetector(
                        onTap: () => Get.toNamed('/sign-in'),
                        child: Text(
                          'lbl_GoToSignIn'.tr,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.light,
                                decoration: TextDecoration.underline,
                              ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
