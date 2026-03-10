import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/services/facebook_auth_service.dart';
import 'package:slickbill/feature_auth/services/google_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../getx_controllers/user_controller.dart';
import '../models/user_model.dart';

JsonEncoder encoder = const JsonEncoder.withIndent('  ');

class SupabaseAuthManger {
  final supabseClient = Supabase.instance.client;
  final userController = Get.put(UserController());
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final FacebookAuthService _facebookAuthService = FacebookAuthService();

  List<BankAccount>? _parseIbans(dynamic ibansData) {
    if (ibansData == null) return null;

    try {
      List<dynamic> ibansList;

      // If it's already a List, use it directly
      if (ibansData is List) {
        ibansList = ibansData;
      }
      // If it's a string, decode it first
      else if (ibansData is String) {
        ibansList = jsonDecode(ibansData) as List;
      }
      // If it's neither, return null
      else {
        return null;
      }

      return ibansList
          .map((item) => BankAccount.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error parsing ibans: $e');
      return null;
    }
  }

  Future<bool> loadFreshUser(authUserId, accessToken) async {
    final tokenToUse = accessToken;

    print('TOKEN IN USE: $tokenToUse');

    final userRecordResponse = await supabseClient
        .from('users')
        .select('*')
        .eq('authUserId', authUserId);

    if (userRecordResponse.isEmpty) {
      // Let caller know there is no app user yet
      // throw StateError('USER_NOT_FOUND_IN_PUBLIC_USERS');
      return false;
    }

    final userProfileClassed = UserModel(
      id: userRecordResponse[0]['id'],
      username: userRecordResponse[0]['username'],
      email: userRecordResponse[0]['email'],
      authUserId: userRecordResponse[0]['authUserId'],
      accessToken: tokenToUse,
    );

    final privateUserResponse = await supabseClient
        .from('private_users')
        .select('*')
        .eq('userId', userProfileClassed.id);

    final businessUserResponse = await supabseClient
        .from('business_users')
        .select('*')
        .eq('userId', userProfileClassed.id);

    if (privateUserResponse.length == 0 && businessUserResponse.length == 0) {
      Get.snackbar('Oops..', 'An error occured');
    }

    final ibansData = privateUserResponse.length > 0
        ? privateUserResponse[0]['ibans']
        : businessUserResponse[0]['ibans'];

    final parsedIbans = _parseIbans(ibansData);

    final clientUserClassed = ClientUserModel(
      id: userRecordResponse[0]['id'],
      username: userRecordResponse[0]['username'],
      email: userRecordResponse[0]['email'],
      authUserId: userRecordResponse[0]['authUserId'],
      accessToken: tokenToUse,
      isPrivate: privateUserResponse.length > 0,
      privateUserId:
          privateUserResponse.length > 0 ? privateUserResponse[0]['id'] : null,
      businessUserId: businessUserResponse.length > 0
          ? businessUserResponse[0]['id']
          : null,
      iban: privateUserResponse.length > 0
          ? privateUserResponse[0]['iban']
          : businessUserResponse[0]['iban'],
      ibans: parsedIbans,
      bankAccountName: privateUserResponse.length > 0
          ? privateUserResponse[0]['bankAccountName']
          : businessUserResponse[0]['bankAccountName'],
      firstName: privateUserResponse.length > 0
          ? privateUserResponse[0]['firstName']
          : null,
      lastName: privateUserResponse.length > 0
          ? privateUserResponse[0]['lastName']
          : null,
      fullName: businessUserResponse.length > 0
          ? businessUserResponse[0]['fullName']
          : null,
      publicName: businessUserResponse.length > 0
          ? businessUserResponse[0]['publicName']
          : null,
      strigaUserId: userRecordResponse[0]['strigaUserId'],
      strigaWalletId: userRecordResponse[0]['strigaWalletId'],
      cdpWalletId: userRecordResponse[0]['cdpWalletId'],
    );

    userController.loadUser(clientUserClassed);
    return true;
  }

  Future<void> signOut(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();

    await supabseClient.auth.signOut();

    prefs.remove('password');
  }

  Future<void> signIn(
    String email,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    prefs.setString('email', email);
    prefs.setString('password', password);

    try {
      print('TEEST');
      final AuthResponse response = await supabseClient.auth
          .signInWithPassword(password: password, email: email);

      print('Sign in response: ${response}');

      final session = response.session;
      final user = response.user;

      print('TEEST ');
      print(session?.accessToken);

      if (session == null || user == null) {
        throw Exception('No session or user returned from Supabase');
      }

      if (session != null) {
        await loadFreshUser(user!.id, session.accessToken);

        prefs.setString('email', email);
        prefs.setString('password', password);

        Get.toNamed('/home-screen');

        // final userRecord = userRecordResponse
      }
    } catch (err) {
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() async {
    return _handleOAuthSignIn(
      authProvider: () => _googleAuthService.signInWithGoogle(),
      providerName: 'Google',
    );
  }

  Future<bool> signInWithFacebook() async {
    return _handleOAuthSignIn(
      authProvider: () => _facebookAuthService.signInWithFacebook(),
      providerName: 'Facebook',
    );
  }

  Future<void> signUp(
      String email,
      String password,
      String firstName,
      String lastName,
      String username,
      String iban,
      String accountHolder) async {
    try {
      print('🔄 Starting signup process for: $email');

      const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      final key =
          kDebugMode ? dotenv.env['SUPABASE_ANON_KEY'] ?? '' : _supabaseAnonKey;

      print('🔑 Using key: ${key.isNotEmpty ? "Key found" : "KEY MISSING!"}');

      final response = await Supabase.instance.client.functions
          .invoke('auth-and-settings/create-user', headers: {
        'Authorization': 'Bearer $key'
      }, body: {
        "email": email,
        "password": password,
        "firstName": firstName,
        "lastName": lastName,
        "username": username,
        "iban": iban,
        "accountHolder": accountHolder,
        "isPrivateUser": true
      });

      print('📦 Response status: ${response.status}');
      print('📦 Response data: ${response.data}');

      final data = response.data;

      if (data == null) {
        print('❌ Response data is null');
        throw Exception('No response data from server');
      }

      if (data['isRequestSuccessfull'] == true) {
        print('✅ User created successfully');
        Get.snackbar(
          'Success',
          'Account created! Please check your email to verify.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );

        // Wait a bit before navigating
        await Future.delayed(Duration(seconds: 1));
        Get.offAllNamed('/sign-in');
      } else {
        print('❌ Signup failed: ${data['error']}');
        Get.snackbar(
          'Oops..',
          data['error']?.toString() ?? 'Unknown error occurred',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
        throw Exception(data['error']?.toString() ?? 'Signup failed');
      }
    } catch (err) {
      print('❌ Error in signUp: $err');

      // Show user-friendly error
      Get.snackbar(
        'Error',
        'Failed to create account. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );

      rethrow;
    }
  }

  /// Create a new app user for an existing Supabase auth user (Google, etc.)
  /// Does NOT sign up with email/password – assumes auth.user already exists.
  Future<void> createUserForAuthUser(User authUser) async {
    try {
      final email = authUser.email ?? '';
      final fullName = authUser.userMetadata?['full_name']?.toString() ??
          authUser.userMetadata?['name']?.toString() ??
          '';
      String firstName = '';
      String lastName = '';

      if (fullName.isNotEmpty) {
        final parts = fullName.split(' ');
        firstName = parts.first;
        if (parts.length > 1) {
          lastName = parts.sublist(1).join(' ');
        }
      }

      final username =
          email.isNotEmpty ? email.split('@').first : 'user_${authUser.id}';

      // 1) insert into public.users
      final insertedUser = await supabseClient
          .from('users')
          .insert(<String, dynamic>{
            'username': username,
            'email': email,
            'authUserId': authUser.id,
          })
          .select()
          .single();

      // 2) create default private_users row for this user
      await supabseClient.from('private_users').insert(<String, dynamic>{
        'userId': insertedUser['id'],
        'firstName': firstName,
        'lastName': lastName,
        // other fields (iban, bankAccountName, etc.) can be set later
      });

      print(
          'createUserForAuthUser: created users + private_users for authUserId=${authUser.id}');
    } catch (e) {
      print('Error in createUserForAuthUser: $e');
      rethrow;
    }
  }

  /// Common OAuth sign-in flow for Google, Facebook, etc.
  /// Returns true if successful, false otherwise
  Future<bool> _handleOAuthSignIn({
    required Future<AuthResponse?> Function() authProvider,
    required String providerName,
  }) async {
    try {
      print('🔵 Starting $providerName Sign-In flow...');

      final response = await authProvider();

      if (response == null || response.user == null) {
        print('❌ $providerName Sign-In was cancelled or failed');
        return false;
      }

      final session = response.session;
      final user = response.user;

      if (session == null || user == null) {
        print('❌ No session or user returned from Supabase');
        return false;
      }

      print('🔍 Attempting to load user for authUserId: ${user.id}');

      // Try to load existing user
      final userExists = await loadFreshUser(user.id, session.accessToken);

      if (!userExists) {
        print('📝 User not found in public.users, creating new user...');

        try {
          await createUserForAuthUser(user);
          print('✅ User created in public.users and private_users');

          print('✅ Striga user creation completed');

          print('🔄 Loading enriched user data...');
          await loadFreshUser(user.id, session.accessToken);
          print('✅ Enriched user loaded successfully');
        } catch (createError) {
          print('❌ Error creating user: ${createError.toString()}');
          Get.snackbar(
            'Error',
            'Failed to create user profile: ${createError.toString()}',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );
          return false;
        }
      } else {
        print('✅ User loaded successfully');
      }

      // Handle invoice token navigation
      final invoiceToken = Get.parameters['invoice_token'] ??
          Uri.base.queryParameters['invoice_token'];

      print('✅ $providerName Sign-In complete');
      if (invoiceToken != null && invoiceToken.isNotEmpty) {
        print('🎯 Navigating to public invoice with token: $invoiceToken');
        Get.offAllNamed(
          '/public-invoice-view',
          arguments: {'token': invoiceToken},
        );
      } else {
        print('🏠 Navigating to home screen');
        Get.offAllNamed('/home-screen');
      }

      return true;
    } catch (e) {
      print('❌ Error in $providerName Sign-In flow: ${e.toString()}');
      Get.snackbar(
        'Error',
        '$providerName Sign-In failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
      return false;
    }
  }
}
