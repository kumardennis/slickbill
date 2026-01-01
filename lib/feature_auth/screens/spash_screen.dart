import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/screens/home_screen.dart';
import 'package:slickbill/feature_auth/screens/sign_in.dart';
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

    // Check for OAuth errors in URL (web only)
    if (kIsWeb) {
      final uri = Uri.base;
      final error = uri.queryParameters['error'];
      final errorDescription = uri.queryParameters['error_description'];

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
              backgroundColor: Colors.red.withOpacity(0.1),
              colorText: Colors.red,
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

    if (mounted) {
      if (session != null) {
        print('✅ Splash: active session found, fetching user from DB');

        try {
          // Use SupabaseAuthManager to get user
          await _supabaseAuthManager.loadFreshUser(
              session.user.id, session.accessToken);

          print('🔍 User fetched: ${userController.user.value.email}');
          print(
              '🔍 User privateUserId: ${userController.user.value.privateUserId}');

          final currentRoute = Get.currentRoute;
          final isPublicInvoicePage = currentRoute.contains('/bill/');

          if (kIsWeb) {
            // If it's a public invoice page, stay there
            if (isPublicInvoicePage) {
              print('ℹ️ Public invoice page detected, staying on current page');
              return;
            }
          }

          if (userController.user != null) {
            print('✅ User data loaded: ${userController.user.value.email}');

            print('✅ User data and invoices loaded, navigating to home');

            Get.offAllNamed('/home-screen');
          } else {
            print('❌ User not found or privateUserId is null');
            await Supabase.instance.client.auth.signOut();
            Get.offAllNamed('/sign-in');

            Future.delayed(Duration(milliseconds: 300), () {
              Get.snackbar(
                'Error',
                'Failed to load user profile. Please sign in again.',
                backgroundColor: Colors.red.withOpacity(0.1),
                colorText: Colors.red,
              );
            });
          }
        } catch (e) {
          print('❌ Error fetching user: $e');
          await Supabase.instance.client.auth.signOut();
          Get.offAllNamed('/sign-in');

          Future.delayed(Duration(milliseconds: 300), () {
            Get.snackbar(
              'Error',
              'Error loading user: ${e.toString()}',
              backgroundColor: Colors.red.withOpacity(0.1),
              colorText: Colors.red,
            );
          });
        }
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
