import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:slickbill/config/env_config.dart';
import 'package:slickbill/feature_auth/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleAuthService {
  final supabase = Supabase.instance.client;
  static bool _initialized = false;
  static Future<void>? _initializing;

  GoogleAuthService();

  static Future<void> ensureInitialized() {
    if (_initialized) {
      return Future.value();
    }
    _initializing ??= () async {
      final signIn = GoogleSignIn.instance;
      if (kIsWeb) {
        await signIn.initialize(
          clientId: EnvConfig.googleWebClientId,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await signIn.initialize(
          clientId: EnvConfig.googleIosClientId,
          serverClientId: EnvConfig.googleWebClientId,
        );
      } else {
        await signIn.initialize(
          serverClientId: EnvConfig.googleWebClientId,
        );
      }
      _initialized = true;
    }();
    return _initializing!;
  }

  Future<AuthResponse?> signInWithGoogleAccount(
    GoogleSignInAccount googleAccount,
  ) async {
    String? accessToken;
    try {
      final googleAuthorization = await googleAccount.authorizationClient
          .authorizationForScopes(<String>['email', 'profile']);
      accessToken = googleAuthorization?.accessToken;
    } catch (error) {
      print('Google access token optional: $error');
    }

    final String? idToken = googleAccount.authentication.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw Exception('No ID Token found.');
    }

    return supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<AuthResponse?> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...');
      await ensureInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception(
          'Google Sign-In on web must use the official Google button.',
        );
      }

      final googleAccount = await GoogleSignIn.instance.authenticate();

      print('Google user signed in: ${googleAccount.email}');
      final response = await signInWithGoogleAccount(googleAccount);
      print('Supabase sign-in successful');
      return response;
    } catch (e) {
      print('Error during Google Sign-In: $e');
      rethrow;
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
