import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:slickbill/feature_auth/services/google_auth_service.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:slickbill/feature_auth/widgets/google_gis_button.dart';

class ContinueWithGoogleButton extends HookWidget {
  const ContinueWithGoogleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final authManager = useMemoized(SupabaseAuthManger.new);
    final isReady = useState(!kIsWeb);
    final isBusy = useState(false);

    useEffect(() {
      if (!kIsWeb) {
        return null;
      }

      var cancelled = false;
      StreamSubscription<GoogleSignInAuthenticationEvent>? subscription;

      unawaited(() async {
        try {
          await GoogleAuthService.ensureInitialized();
          if (cancelled) {
            return;
          }
          isReady.value = true;
          subscription =
              GoogleSignIn.instance.authenticationEvents.listen((event) async {
            if (cancelled || isBusy.value) {
              return;
            }
            if (event is! GoogleSignInAuthenticationEventSignIn) {
              return;
            }
            isBusy.value = true;
            try {
              await authManager.signInWithGoogleAccount(event.user);
            } finally {
              if (!cancelled) {
                isBusy.value = false;
              }
            }
          });
        } catch (error) {
          debugPrint('Google Sign-In init failed: $error');
        }
      }());

      return () {
        cancelled = true;
        subscription?.cancel();
      };
    }, const []);

    if (kIsWeb) {
      final width = MediaQuery.of(context).size.width - 80;
      final buttonWidth = width.clamp(240.0, 400.0);
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: !isReady.value || isBusy.value
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: googleGisSignInButton(minimumWidth: buttonWidth),
              ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isBusy.value
            ? null
            : () async {
                isBusy.value = true;
                try {
                  await authManager.signInWithGoogle();
                } finally {
                  isBusy.value = false;
                }
              },
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
            const Text(
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
    );
  }
}
