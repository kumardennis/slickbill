import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/shared_widgets/input_field.dart';
import '../services/google_auth_service.dart';
import '../utils/supabase_auth_manger.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SignUp extends HookWidget {
  SignUp({Key? key}) : super(key: key);

  final _supabase = SupabaseAuthManger();
  final _googleAuthService = GoogleAuthService();

  @override
  Widget build(BuildContext context) {
    TextEditingController? email = useTextEditingController();
    TextEditingController? password = useTextEditingController();
    TextEditingController? confirmPassword = useTextEditingController();
    TextEditingController? firstName = useTextEditingController();
    TextEditingController? lastName = useTextEditingController();
    TextEditingController? username = useTextEditingController();
    TextEditingController? iban = useTextEditingController();
    TextEditingController? accountHolder = useTextEditingController();

    final isLoading = useState<bool>(false); // ✅ Add loading state

    void signUp() async {
      // ✅ Add email validation
      if (email.text.isEmpty || !email.text.contains('@')) {
        Get.snackbar('Oops..', 'Please enter a valid email');
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

      if (username.text.isEmpty) {
        Get.snackbar('Oops..', 'Username is kinda important');
        return;
      }

      if (iban.text.isEmpty || accountHolder.text.isEmpty) {
        Get.snackbar('Oops..', 'Please add your shareable bank info...');
        return;
      }

      // ✅ Show loading state
      isLoading.value = true;

      try {
        print('🔄 Starting signup for: ${email.text}'); // ✅ Debug log

        await _supabase.signUp(
          email.text,
          password.text,
          firstName.text,
          lastName.text,
          username.text,
          iban.text,
          accountHolder.text,
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

    void googleSignUp() async {
      try {
        if (kIsWeb) {
          await _googleAuthService.signInWithGoogleWeb();
        } else {
          final success = await _supabase.signInWithGoogle();
          if (success) {
            Get.offAllNamed('/home-screen');
          }
        }
      } catch (e) {
        Get.snackbar('Error', 'Google Sign-Up failed: $e');
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

                      // Google Sign-Up Button - PRIORITY
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: googleSignUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 2,
                            shadowColor: Colors.black26,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/g-logo.png',
                                height: 24,
                                width: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

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
                      InputField(
                        controller: firstName,
                        label: 'lbl_FirstName'.tr,
                        obscure: false,
                      ),
                      InputField(
                        controller: lastName,
                        label: 'lbl_LastName'.tr,
                        obscure: false,
                      ),
                      InputField(
                        controller: username,
                        label: 'lbl_Username'.tr,
                        obscure: false,
                      ),
                      InputField(
                        controller: iban,
                        label: 'lbl_IBAN'.tr,
                        obscure: false,
                      ),
                      InputField(
                        controller: accountHolder,
                        label: 'lbl_AccountHolder'.tr,
                        obscure: false,
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
