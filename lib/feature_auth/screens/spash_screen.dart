import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/core/services/push_notification_service.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/screens/home_screen.dart';
import 'package:slickbill/feature_auth/screens/sign_in.dart';
import 'package:slickbill/feature_auth/services/deep_links.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:slickbill/feature_auth/services/google_auth_service.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _supabaseAuthManager = SupabaseAuthManger();
  final UserController userController =
      Get.put<UserController>(UserController());

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));

    bool isFromGoogleOAuth = false;
    bool isFromFacebookOAuth = false;
    String? invoiceToken;

    // ✅ Check if this is a deep link navigation
    final currentRoute = Get.currentRoute;
    final isBillDeepLink = currentRoute.startsWith('/bill/');

    if (isBillDeepLink) {
      print(
          '🔗 Bill deep link detected in splash, preserving route: $currentRoute');
      // Don't navigate away, let the deep link handler take over
      return;
    }

    // Check for OAuth callback
    if (kIsWeb) {
      final uri = Uri.base;
      final error = uri.queryParameters['error'];
      final errorDescription = uri.queryParameters['error_description'];
      final fromParam = uri.queryParameters['from'];
      final tokenParam = uri.queryParameters['invoice_token'];

      if (fromParam == 'google_oauth') {
        isFromGoogleOAuth = true;
        invoiceToken = tokenParam;
        print('🔍 Detected Google OAuth callback');
        if (invoiceToken != null) {
          print('🔍 Invoice token preserved: $invoiceToken');
        }
      }

      if (fromParam == 'facebook_oauth') {
        isFromFacebookOAuth = true;
        invoiceToken = tokenParam;
        print('🔍 Detected Facebook OAuth callback');
        if (invoiceToken != null) {
          print('🔍 Invoice token preserved: $invoiceToken');
        }
      }

      if (error != null) {
        print('❌ OAuth error in URL: $error - $errorDescription');
        await Future.delayed(Duration(milliseconds: 100));

        if (mounted) {
          Get.offAllNamed('/sign-in');

          Future.delayed(Duration(milliseconds: 300), () {
            Get.snackbar(
              'Sign In Failed',
              errorDescription ??
                  'Google authentication was cancelled or failed',
              backgroundColor: Theme.of(context).colorScheme.red,
              colorText: Colors.white,
              duration: const Duration(seconds: 5),
            );
          });
        }
        return;
      }
    }

    final session = Supabase.instance.client.auth.currentSession;

    print('🔍 Splash: Session exists: ${session != null}');
    if (session != null) {
      print('🔍 Auth User ID: ${session.user.id}');
      print('🔍 Auth User Email: ${session.user.email}');
      print('🔍 Access Token present: ${session.accessToken.isNotEmpty}');
    }

    final isPublicInvoicePage = currentRoute.contains('/bill/') ||
        currentRoute.contains('/public-invoice/');

    if (mounted) {
      if (session != null) {
        print('✅ Splash: active session found, fetching user from DB');

        try {
          final userLoaded = await _supabaseAuthManager.loadFreshUser(
              session.user.id, session.accessToken);

          if (!userLoaded) {
            print('⚠️ User not found in database');

            // Only create user if coming from Google OAuth
            if (isFromGoogleOAuth || isFromFacebookOAuth) {
              print('📝 Creating user from Google OAuth...');

              try {
                await _supabaseAuthManager.createUserForAuthUser(session.user);
                print('✅ User created successfully');

                // Try loading again
                final retryLoaded = await _supabaseAuthManager.loadFreshUser(
                    session.user.id, session.accessToken);

                if (!retryLoaded) {
                  throw Exception('Failed to load user after creation');
                }
              } catch (createError) {
                print('❌ Error creating user: $createError');
                await Supabase.instance.client.auth.signOut();
                Get.offAllNamed('/sign-in');

                Future.delayed(Duration(milliseconds: 300), () {
                  Get.snackbar(
                    'Error',
                    'Failed to create user profile. Please try again.',
                    backgroundColor: Theme.of(context).colorScheme.red,
                    colorText: Colors.white,
                  );
                });
                return;
              }
            } else {
              // User exists in auth but not in public.users, and didn't come from OAuth
              print('❌ User exists in auth but not in database');
              await Supabase.instance.client.auth.signOut();
              Get.offAllNamed('/sign-in');

              Future.delayed(Duration(milliseconds: 300), () {
                Get.snackbar(
                  'Error',
                  'User profile not found. Please sign up first.',
                  backgroundColor: Theme.of(context).colorScheme.red,
                  colorText: Colors.white,
                );
              });
              return;
            }
          }

          print('🔍 User fetched: ${userController.user.value.email}');
          print(
              '🔍 User privateUserId: ${userController.user.value.privateUserId}');

          final oneSignalExternalId =
              (userController.user.value.privateUserId ??
                      userController.user.value.id)
                  .toString();
          await PushNotificationService.loginUser(oneSignalExternalId);

          // If came from OAuth with invoice token, redirect to that invoice
          if ((isFromGoogleOAuth || isFromFacebookOAuth) &&
              invoiceToken != null) {
            print('✅ Redirecting to invoice: $invoiceToken');
            Get.offAllNamed('/bill/$invoiceToken');
            return;
          }

          // ✅ If it's a public invoice page OR bill deep link, stay there
          if (isPublicInvoicePage || isBillDeepLink) {
            print(
                'ℹ️ Invoice page detected, staying on current page: $currentRoute');
            return;
          }

          if (userController.user.value.privateUserId != null) {
            print('✅ User data loaded: ${userController.user.value.email}');
            print('✅ Navigating to home');
            Get.offAllNamed('/home-screen');
          } else {
            print('❌ User privateUserId is null');
            await Supabase.instance.client.auth.signOut();
            Get.offAllNamed('/sign-in');

            Future.delayed(Duration(milliseconds: 300), () {
              Get.snackbar(
                'Error',
                'Failed to load user profile. Please sign in again.',
                backgroundColor: Theme.of(context).colorScheme.red,
                colorText: Colors.white,
              );
            });
          }
        } catch (e) {
          print('❌ Error in auth flow: $e');
          await Supabase.instance.client.auth.signOut();
          Get.offAllNamed('/sign-in');

          Future.delayed(Duration(milliseconds: 300), () {
            Get.snackbar(
              'Error',
              'Error loading user: ${e.toString()}',
              backgroundColor: Theme.of(context).colorScheme.red,
              colorText: Colors.white,
            );
          });
        }
      } else {
        print('ℹ️ Splash: no active session');

        // ✅ If it's a public invoice page or bill deep link, allow access without auth
        if (isPublicInvoicePage || isBillDeepLink) {
          print(
              'ℹ️ Invoice page detected, allowing access without auth: $currentRoute');
          return;
        }

        Get.offAllNamed('/sign-in');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
