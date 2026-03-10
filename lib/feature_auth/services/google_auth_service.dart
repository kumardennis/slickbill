import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:slickbill/config/env_config.dart';
import 'package:slickbill/feature_auth/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleAuthService {
  final supabase = Supabase.instance.client;

  GoogleAuthService();

  Future<AuthResponse?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...');

      final GoogleSignIn signIn = GoogleSignIn.instance;

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        unawaited(
          signIn.initialize(
            clientId: EnvConfig.googleIosClientId,
            serverClientId: EnvConfig.googleWebClientId,
          ),
        );
      } else {
        unawaited(
            signIn.initialize(serverClientId: EnvConfig.googleWebClientId));
      }

      final googleAccount = await signIn.authenticate();

      if (googleAccount == null) {
        print('Google Sign-In cancelled by user');
        return null;
      }

      print('Google user signed in: ${googleAccount.email}');

      final googleAuthorization = await googleAccount.authorizationClient
          .authorizationForScopes(<String>['email', 'profile']);

      final googleAuthentication = googleAccount.authentication;
      final String? idToken = googleAuthentication.idToken;
      final String? accessToken = googleAuthorization?.accessToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      print('Got Google ID token, signing in to Supabase...');

      final AuthResponse response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      print('Supabase sign-in successful');
      return response;
    } catch (e) {
      print('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  Future<void> signInWithGoogleWeb() async {
    if (kIsWeb) {
      try {
        final currentUri = Uri.base;
        final path = currentUri.path;

        // Extract invoice token from /bill/<token> or /sign-in?invoice_token=...
        String? invoiceToken;
        if (path.startsWith('/bill/')) {
          invoiceToken = path.replaceFirst('/bill/', '');
        } else {
          invoiceToken = currentUri.queryParameters['invoice_token'];
        }

        String redirectUrl;
        if (currentUri.host.contains('localhost')) {
          redirectUrl = invoiceToken != null && invoiceToken.isNotEmpty
              ? 'http://localhost:3000/sign-in?invoice_token=$invoiceToken'
              : 'http://localhost:3000/sign-in';
        } else {
          redirectUrl = invoiceToken != null && invoiceToken.isNotEmpty
              ? 'https://app.slickbills.com/sign-in?invoice_token=$invoiceToken'
              : 'https://app.slickbills.com/sign-in';
        }

        print('🔵 OAuth redirect URL: $redirectUrl');
        print('🔵 Preserving invoice token: $invoiceToken');

        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
          authScreenLaunchMode: LaunchMode.platformDefault,
        );
      } catch (e) {
        print('❌ OAuth error: $e');
        Get.snackbar(
          'Sign In Failed',
          'Could not sign in with Google. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        rethrow;
      }
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      print('Signed out from Google');
    } catch (e) {
      print('Error signing out from Google: $e');
    }
  }

  /// Ensure a row exists in public.users for this auth user.
  /// OBSOLETE
  Future<ClientUserModel?> createOrGetUser(User supabaseUser) async {
    try {
      print('Checking/creating user row in users table...');

      // 1. Check existing user
      final existingUser = await supabase
          .from('users')
          .select()
          .eq('authUserId', supabaseUser.id)
          .maybeSingle();

      if (existingUser != null) {
        print('Existing user found in users table');

        return ClientUserModel(
          id: existingUser['id'] as int,
          username: (existingUser['username'] ?? '') as String,
          email: (existingUser['email'] ?? '') as String,
          authUserId: (existingUser['authUserId'] ?? '') as String,
          accessToken: '',
          // add any other fields with safe defaults:
          firstName: (existingUser['firstName'] ?? '') as String? ?? '',
          lastName: (existingUser['lastName'] ?? '') as String? ?? '',
          isPrivate: true,
          strigaUserId: (existingUser['strigaUserId'] ?? '') as String? ?? '',
          strigaWalletId:
              (existingUser['strigaWalletId'] ?? '') as String? ?? '',
        );
      }

      // 2. Create new row
      final email = supabaseUser.email ?? '';
      final username =
          email.isNotEmpty ? email.split('@').first : 'user_${supabaseUser.id}';

      final insertedUser = await supabase
          .from('users')
          .insert(<String, dynamic>{
            'username': username,
            'email': email,
            'authUserId': supabaseUser.id,
          })
          .select()
          .single();

      print('New user row created in users table: id=${insertedUser['id']}');

      return ClientUserModel(
        id: insertedUser['id'] as int,
        username: (insertedUser['username'] ?? '') as String,
        email: (insertedUser['email'] ?? '') as String,
        authUserId: (insertedUser['authUserId'] ?? '') as String,
        accessToken: '',
        firstName: '',
        lastName: '',
        isPrivate: true,
      );
    } catch (e) {
      print('Error creating/getting user: $e');
      rethrow;
    }
  }
}
