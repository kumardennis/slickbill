import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_auth/services/web_tab.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FacebookAuthService {
  final supabase = Supabase.instance.client;

  Future<AuthResponse?> signInWithFacebook() async {
    try {
      if (kIsWeb) {
        final invoiceToken = Get.parameters['invoice_token'] ??
            Uri.base.queryParameters['invoice_token'];
        slickBillsMarkWebOAuthPending(invoiceToken: invoiceToken);

        final res = await supabase.auth.getOAuthSignInUrl(
          provider: OAuthProvider.facebook,
          redirectTo: _webRedirectTo(),
          scopes: 'email,public_profile',
        );
        // url_launcher uses window.open(..., noopener) which becomes a new tab.
        slickBillsAssignCurrentTab(res.url);
        return null;
      }

      await supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'slickbills://home-screen',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      final session = supabase.auth.currentSession;
      final user = session?.user;

      if (session != null && user != null) {
        return AuthResponse(session: session, user: user);
      }

      return null;
    } catch (e) {
      print('❌ Facebook authentication error: ${e.toString()}');
      rethrow;
    }
  }

  String _webRedirectTo() {
    final origin = Uri.base.origin;
    if (origin.contains('localhost') || origin.contains('127.0.0.1')) {
      return '$origin/sign-in';
    }
    return 'https://app.slickbills.com/sign-in';
  }
}
