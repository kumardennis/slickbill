import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/core/services/push_notification_service.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/screens/home_screen.dart';
import 'package:slickbill/feature_auth/services/facebook_auth_service.dart';
import 'package:slickbill/feature_auth/services/google_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../utils/supabase_auth_manger.dart';

class SignIn extends HookWidget {
  final String? invoice_token;
  const SignIn({Key? key, this.invoice_token}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _supabase = SupabaseAuthManger();
    final _googleAuthService = GoogleAuthService();
    final _facebookAuthService = FacebookAuthService();
    final UserController userController = Get.find<UserController>();

    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    ValueNotifier<bool> isLoadingOAuth = useState<bool>(false);

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

          // Get the newly created user ID
          final userRecord = await _supabase.supabseClient
              .from('users')
              .select('id')
              .eq('authUserId', user.id)
              .single();

          final appUserId = userRecord['id'] as int;

          // Load the user again
          await _supabase.loadFreshUser(user.id, accessToken);
        }

        // ✅ Login user to OneSignal after successful auth
        final oneSignalExternalId = (userController.user.value.privateUserId ??
                userController.user.value.id)
            .toString();
        await PushNotificationService.loginUser(oneSignalExternalId);

        print('✅ User loaded successfully');
        print('🔍 Invoice token after OAuth: $invoiceToken');

        isLoadingOAuth.value = false;

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

    // Handle OAuth callback on page load
    useEffect(() {
      if (kIsWeb) {
        Future.delayed(const Duration(milliseconds: 1000), () async {
          final currentUri = Uri.base;
          final hasOAuthCode = currentUri.queryParameters.containsKey('code');

          print('🔍 Has OAuth code: $hasOAuthCode');
          print('🔍 Current URL: ${currentUri.toString()}');

          if (hasOAuthCode) {
            print('⏳ OAuth callback detected, processing...');

            // Wait a bit for Supabase to process the OAuth callback
            await Future.delayed(const Duration(milliseconds: 500));

            final session = Supabase.instance.client.auth.currentSession;

            if (session != null) {
              final user = session.user;
              if (user != null) {
                print('✅ Processing OAuth sign-in for user: ${user.id}');
                await _processOAuthSignIn(
                    user, session.accessToken, getInvoiceToken());
              }
            } else {
              print('❌ No session found after OAuth');
            }
          }
        });
      }
      return null;
    }, []);

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

        final invoiceToken = getInvoiceToken();

        print('🔍 Invoice token after sign-in: $invoiceToken');

        final oneSignalExternalId = (userController.user.value.privateUserId ??
                userController.user.value.id)
            .toString();
        await PushNotificationService.loginUser(oneSignalExternalId);

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

        Get.snackbar(
          'Error',
          'Failed to sign in: ${e.toString()}',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }

    void googleSignIn() async {
      try {
        if (kIsWeb) {
          // Web: use OAuth redirect flow
          // This will redirect to Supabase OAuth, then back to /sign-in
          await _googleAuthService.signInWithGoogleWeb();
        } else {
          // Mobile: use native Google Sign-In
          final success = await _supabase.signInWithGoogle();
          if (success) {
            final invoiceToken = getInvoiceToken();
            final oneSignalExternalId =
                (userController.user.value.privateUserId ??
                        userController.user.value.id)
                    .toString();
            await PushNotificationService.loginUser(oneSignalExternalId);
            if (invoiceToken != null && invoiceToken.isNotEmpty) {
              Get.offAllNamed(
                '/bill/$invoiceToken',
              );
            } else {
              Get.offAllNamed('/home-screen');
            }
          }
        }
      } catch (e) {
        Get.snackbar('Error', 'Google Sign-In failed: $e');
      }
    }

    void facebookSignIn() async {
      try {
        final success = await _supabase.signInWithFacebook();
        if (success) {
          final invoiceToken = getInvoiceToken();
          final oneSignalExternalId =
              (userController.user.value.privateUserId ??
                      userController.user.value.id)
                  .toString();
          await PushNotificationService.loginUser(oneSignalExternalId);
          if (invoiceToken != null && invoiceToken.isNotEmpty) {
            Get.offAllNamed(
              '/bill/$invoiceToken',
            );
          } else {
            Get.offAllNamed('/home-screen');
          }
        }
      } catch (e) {
        Get.snackbar('Error', 'Facebook Sign-In failed: $e');
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
              child: isLoadingOAuth.value
                  ? const Center(child: CircularProgressIndicator())
                  : GestureDetector(
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
                                child:
                                    Image.asset('assets/logo_text_darkbg.png'),
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Google Sign-In Button - PRIORITY
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: googleSignIn,
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

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: facebookSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF1877F2),
                                  foregroundColor: Colors.white,
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
                                      'assets/fb-logo.png',
                                      height: 24,
                                      width: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Continue with Facebook',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
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

                            // Email Input
                            SizedBox(
                              width: double.infinity,
                              child: TextFormField(
                                controller: emailController,
                                autofocus: false,
                                obscureText: false,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.light,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'lbl_Username'.tr,
                                  labelStyle: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .light
                                        .withOpacity(0.7),
                                  ),
                                  hintStyle: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .light
                                        .withOpacity(0.5),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .light
                                          .withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.light,
                                      width: 2,
                                    ),
                                  ),
                                  suffixIcon: emailController.text.isNotEmpty
                                      ? InkWell(
                                          onTap: () => emailController.clear(),
                                          child: Icon(
                                            Icons.clear,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .light,
                                            size: 22,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Password Input
                            SizedBox(
                              width: double.infinity,
                              child: TextFormField(
                                controller: passwordController,
                                autofocus: false,
                                obscureText: true,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.light,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'lbl_Password'.tr,
                                  labelStyle: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .light
                                        .withOpacity(0.7),
                                  ),
                                  hintStyle: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .light
                                        .withOpacity(0.5),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .light
                                          .withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.light,
                                      width: 2,
                                    ),
                                  ),
                                  suffixIcon: passwordController.text.isNotEmpty
                                      ? InkWell(
                                          onTap: () =>
                                              passwordController.clear(),
                                          child: Icon(
                                            Icons.clear,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .light,
                                            size: 22,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Sign In Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.blue,
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'btn_SignIn'.tr,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.light,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Sign Up Link
                            GestureDetector(
                              onTap: () => Get.toNamed('/sign-up'),
                              child: Text(
                                'lbl_GoToSignUp'.tr,
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.light,
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
