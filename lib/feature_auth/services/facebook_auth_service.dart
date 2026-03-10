import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FacebookAuthService {
  final supabase = Supabase.instance.client;

  Future<AuthResponse?> signInWithFacebook() async {
    try {
      if (kIsWeb) {
        // ✅ Web: Use OAuth redirect
        await supabase.auth.signInWithOAuth(
          OAuthProvider.facebook,
          redirectTo: 'https://app.slickbills.com/sign-in?from=facebook_oauth',
          authScreenLaunchMode: LaunchMode.platformDefault,
        );
        return null; // Will redirect and come back
      } else {
        // ✅ Mobile: Launch in external browser with deep link
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
      }
    } catch (e) {
      print('❌ Facebook authentication error: ${e.toString()}');
      rethrow;
    }
  }
}
