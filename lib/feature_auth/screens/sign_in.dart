import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:slickbill/feature_auth/getx_controllers/app_lock_controller.dart';
import 'package:slickbill/feature_auth/services/web_tab.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:slickbill/feature_auth/widgets/auth_page_scaffold.dart';
import 'package:slickbill/feature_auth/widgets/continue_with_google_button.dart';
import 'package:slickbill/theme/sb_colors.dart';

class SignIn extends HookWidget {
  final String? invoice_token;
  const SignIn({Key? key, this.invoice_token}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _supabase = SupabaseAuthManger();

    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    ValueNotifier<bool> isLoadingOAuth = useState<bool>(false);
    final isResendingVerification = useState<bool>(false);
    final showResendVerification = useState<bool>(false);

    // Get invoice token from URL if present
    String? getInvoiceToken() {
      // Constructor parameter takes precedence
      if (invoice_token != null && invoice_token!.isNotEmpty) {
        return invoice_token;
      }
      // Fall back to Get.parameters or query params
      return Get.parameters['invoice_token'] ??
          Uri.base.queryParameters['invoice_token'];
    }

    bool _isEmailConfirmationCallback(Uri uri) {
      if (uri.queryParameters['verified'] == '1') {
        return true;
      }

      final type = (uri.queryParameters['type'] ?? '').toLowerCase();
      if (type == 'signup' || type == 'email' || type == 'email_change') {
        return true;
      }

      final fragment = uri.fragment;
      if (fragment.isEmpty) {
        return false;
      }

      final fragmentParams = Uri.splitQueryString(fragment);
      final fragmentType = (fragmentParams['type'] ?? '').toLowerCase();
      return fragmentType == 'signup' ||
          fragmentType == 'email' ||
          fragmentType == 'email_change';
    }

    bool _isEmailNotConfirmedError(Object error) {
      final message = error.toString().toLowerCase();
      return message.contains('email_not_confirmed') ||
          message.contains('email not confirmed') ||
          message.contains('confirm your email') ||
          message.contains('verify your email');
    }

    String _signInErrorMessage(Object error) {
      if (_isEmailNotConfirmedError(error)) {
        return 'Please verify your email before signing in. Check your inbox, or resend the verification email below.';
      }
      return 'Failed to sign in: ${error.toString()}';
    }

    // Extract OAuth processing to a separate function
    Future<void> _processOAuthSignIn(
        User user, String accessToken, String? invoiceToken) async {
      isLoadingOAuth.value = true;

      try {
        print('🔄 Auth user ID: ${user.id}');
        print('🔍 Attempting to load fresh user...');

        // ✅ CHECK THE BOOLEAN RETURN VALUE
        final userExists = await _supabase.loadFreshUser(user.id, accessToken);

        if (!userExists) {
          print('📝 User not found, creating...');
          await _supabase.createUserForAuthUser(user);

          // Load the user again
          await _supabase.loadFreshUser(user.id, accessToken);
        }

        // Push token sync now happens in UserController.loadUser.

        print('✅ User loaded successfully');
        print('🔍 Invoice token after OAuth: $invoiceToken');

        isLoadingOAuth.value = false;

        AppLockController.markInteractiveLogin();

        // Navigate
        if (invoiceToken != null && invoiceToken.isNotEmpty) {
          print('🎯 Navigating to invoice: $invoiceToken');
          Get.offAllNamed('/public-invoice-view',
              arguments: {'token': invoiceToken});
        } else {
          print('🏠 Navigating to /home-screen');
          Get.offAllNamed('/home-screen');
        }
      } catch (e) {
        print('❌ Error in _processOAuthSignIn: $e');
        isLoadingOAuth.value = false;
        Get.snackbar(
          'Error',
          'Failed to process sign-in: ${e.toString()}',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
      } finally {
        isLoadingOAuth.value = false;
      }
    }

    // Handle OAuth / email-confirmation callback on page load
    useEffect(() {
      if (!kIsWeb) {
        return null;
      }

      var cancelled = false;
      var completing = false;

      Future<void> completeOAuthIfPossible() async {
        if (cancelled || completing) return;
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return;

        completing = true;
        try {
          final invoiceToken = getInvoiceToken() ??
              slickBillsPeekWebOAuthInvoiceToken();
          await _processOAuthSignIn(
            session.user,
            session.accessToken,
            invoiceToken,
          );
          slickBillsClearWebOAuthPending();
        } finally {
          completing = false;
        }
      }

      Future<void> handleWebCallback() async {
        final currentUri = Uri.base;
        final fragmentParams = Uri.splitQueryString(currentUri.fragment);
        final hasOAuthCode = currentUri.queryParameters.containsKey('code') ||
            fragmentParams.containsKey('code');
        final oauthError = currentUri.queryParameters['error'] ??
            fragmentParams['error'];
        final isEmailConfirmation = _isEmailConfirmationCallback(currentUri);

        print('🔍 Has OAuth code: $hasOAuthCode');
        print('🔍 Is email confirmation: $isEmailConfirmation');
        print('🔍 Current URL: ${currentUri.toString()}');

        if (isEmailConfirmation) {
          try {
            await Supabase.instance.client.auth.signOut();
          } catch (_) {}
          if (cancelled) return;
          Get.snackbar(
            'Email verified',
            'Your email is confirmed. Please sign in to continue.',
            backgroundColor: Colors.green.withOpacity(0.15),
            colorText: Colors.green.shade800,
            duration: const Duration(seconds: 4),
          );
          return;
        }

        if (oauthError != null && oauthError.isNotEmpty) {
          final description = currentUri.queryParameters['error_description'] ??
              fragmentParams['error_description'] ??
              'Facebook sign-in was cancelled or failed.';
          Get.snackbar(
            'Sign in failed',
            description,
            backgroundColor: Theme.of(context).colorScheme.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          slickBillsClearWebOAuthPending();
          return;
        }

        if (hasOAuthCode) {
          isLoadingOAuth.value = true;
          try {
            await Supabase.instance.client.auth.getSessionFromUrl(currentUri);
          } catch (error) {
            print('❌ OAuth code exchange: $error');
          }
        }

        await completeOAuthIfPossible();

        if (!cancelled &&
            Supabase.instance.client.auth.currentSession == null &&
            (hasOAuthCode || slickBillsHasWebOAuthPending())) {
          await Future.delayed(const Duration(milliseconds: 800));
          await completeOAuthIfPossible();
          if (Supabase.instance.client.auth.currentSession == null) {
            isLoadingOAuth.value = false;
            Get.snackbar(
              'Sign in failed',
              'Facebook sign-in did not complete. Please try again.',
              backgroundColor: Theme.of(context).colorScheme.red,
              colorText: Colors.white,
            );
          }
        }
      }

      final sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event != AuthChangeEvent.signedIn) return;
        if (!slickBillsHasWebOAuthPending() &&
            !Uri.base.queryParameters.containsKey('code')) {
          return;
        }
        unawaited(completeOAuthIfPossible());
      });

      unawaited(handleWebCallback());

      return () {
        cancelled = true;
        sub.cancel();
      };
    }, []);

    Future<void> resendVerification() async {
      final email = emailController.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        Get.snackbar(
          'Email required',
          'Enter the email you signed up with, then tap Resend.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }

      isResendingVerification.value = true;
      try {
        await _supabase.resendSignupVerificationEmail(email);
        Get.snackbar(
          'Verification sent',
          'Check your inbox for a new verification link.',
          backgroundColor: Colors.green.withOpacity(0.15),
          colorText: Colors.green.shade800,
          duration: const Duration(seconds: 4),
        );
      } catch (e) {
        Get.snackbar(
          'Could not resend',
          e.toString(),
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
      } finally {
        isResendingVerification.value = false;
      }
    }

    void signIn() async {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        Get.snackbar(
          'Error',
          'Please enter both email and password',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }

      try {
        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );
        await _supabase.signIn(email, password);

        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        showResendVerification.value = false;

        AppLockController.markInteractiveLogin();

        final invoiceToken = getInvoiceToken();

        print('🔍 Invoice token after sign-in: $invoiceToken');

        // Navigate based on whether we have an invoice token
        if (invoiceToken != null && invoiceToken.isNotEmpty) {
          Get.offAllNamed('/bill/$invoiceToken');
        } else {
          Get.offAllNamed('/home-screen');
        }

        Get.snackbar(
          'Success',
          'Signed in successfully',
          backgroundColor: Colors.green.withOpacity(0.1),
          colorText: Colors.green,
          duration: const Duration(seconds: 2),
        );
      } catch (e) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        debugPrint(e.toString());
        final notConfirmed = _isEmailNotConfirmedError(e);
        showResendVerification.value = notConfirmed;

        Get.snackbar(
          notConfirmed ? 'Verify your email' : 'Error',
          _signInErrorMessage(e),
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    }

    void facebookSignIn() async {
      try {
        if (kIsWeb) {
          isLoadingOAuth.value = true;
        }
        final success = await _supabase.signInWithFacebook();
        if (success) {
          AppLockController.markInteractiveLogin();
          final invoiceToken = getInvoiceToken();

          if (invoiceToken != null && invoiceToken.isNotEmpty) {
            Get.offAllNamed(
              '/bill/$invoiceToken',
            );
          } else {
            Get.offAllNamed('/home-screen');
          }
        }
      } catch (e) {
        isLoadingOAuth.value = false;
        Get.snackbar('Error', 'Facebook Sign-In failed: $e');
      }
    }

    return AuthPageScaffold(
      title: 'lbl_AuthSignInTitle'.tr,
      subtitle: 'lbl_AuthSubtitle'.tr,
      isLoading: isLoadingOAuth.value,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ContinueWithGoogleButton(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: facebookSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SbRadii.md),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/fb-logo.png',
                      height: 20,
                      width: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Continue with Facebook',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const AuthOrDivider(),
            const SizedBox(height: 20),
            AuthTextField(
              controller: emailController,
              label: 'lbl_Email'.tr,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            AuthTextField(
              controller: passwordController,
              label: 'lbl_Password'.tr,
              obscure: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'btn_SignIn'.tr,
              onPressed: signIn,
            ),
            if (showResendVerification.value) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: isResendingVerification.value
                    ? null
                    : resendVerification,
                child: isResendingVerification.value
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SbColors.deepNavy,
                        ),
                      )
                    : Text(
                        'Resend verification email',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: SbColors.deepNavy,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
              ),
            ],
            const SizedBox(height: 16),
            AuthFooterLink(
              prompt: 'lbl_AuthNoAccount'.tr,
              action: 'lbl_AuthSignUpAction'.tr,
              onTap: () => Get.toNamed('/sign-up'),
            ),
          ],
        ),
      ),
    );
  }
}
