import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
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

  Future<void> loadFreshUser(authUserId, accessToken) async {
    final tokenToUse = accessToken;

    print('TOKEN IN USE: $tokenToUse');

    final userRecordResponse = await supabseClient
        .from('users')
        .select('*')
        .eq('authUserId', authUserId);

    if (userRecordResponse.isEmpty) {
      // Let caller know there is no app user yet
      throw StateError('USER_NOT_FOUND_IN_PUBLIC_USERS');
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
      strigaUserId: privateUserResponse[0]['strigaUserId'],
      strigaWalletId: privateUserResponse[0]['strigaWalletId'],
    );

    userController.loadUser(clientUserClassed);
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

      if (session != null) {
        await loadFreshUser(user!.id, session.accessToken);

        prefs.setString('email', email);
        prefs.setString('password', password);

        Get.toNamed('/home-screen');

        // final userRecord = userRecordResponse
      }
    } catch (err) {
      debugPrint(err.toString());
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In flow...');

      final response = await _googleAuthService.signInWithGoogle();

      if (response == null || response.user == null) {
        print('Google Sign-In was cancelled or failed');
        return false;
      }

      final session = response.session;
      final user = response.user;

      if (session == null || user == null) {
        print('No session or user returned from Supabase');
        return false;
      }

      try {
        // Try to load app user (users + private_users + striga stuff)
        await loadFreshUser(user.id, session.accessToken);
      } on StateError catch (e) {
        if (e.message == 'USER_NOT_FOUND_IN_PUBLIC_USERS') {
          // 1) create users + private_users rows
          await createUserForAuthUser(user);

          // 2) load again to get the new app user id
          final userRecordResponse = await supabseClient
              .from('users')
              .select('id')
              .eq('authUserId', user.id);

          if (userRecordResponse.isNotEmpty) {
            final appUserId = userRecordResponse[0]['id'] as int;

            // 3) call Striga create-user function to enrich
            await _createStrigaUserFor(appUserId, session.accessToken);
          }

          // 4) load enriched user into UserController
          await loadFreshUser(user.id, session.accessToken);
        } else {
          rethrow;
        }
      }

      Get.toNamed('/home-screen');
      print('Google Sign-In complete, user saved');
      return true;
    } catch (e) {
      print('Error in Google Sign-In: $e');
      return false;
    }
  }

  Future<void> signUp(
      String email,
      String password,
      String firstNanme,
      String lastName,
      String username,
      String iban,
      String accountHolder) async {
    try {
      final _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      final response = await Supabase.instance.client.functions
          .invoke('auth-and-settings/create-user', headers: {
        'Authorization':
            'Bearer ${kDebugMode ? dotenv.env['SUPABASE_ANON_KEY'] ?? '' : _supabaseAnonKey}'
      }, body: {
        "email": email,
        "password": password,
        "firstName": firstNanme,
        "lastName": lastName,
        "username": username,
        "iban": iban,
        "accountHolder": accountHolder,
        "isPrivateUser": true
      });

      final data = await response.data;

      if (data['isRequestSuccessfull'] == true) {
        Get.snackbar('Success..', 'User created!');
        Get.toNamed('/sign-in');
      } else {
        Get.snackbar('Oops..', data['error'].toString());
      }
    } catch (err) {
      print(err);
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

  /// Call the Striga `create-user` Edge Function for a given app user ID
  Future<void> _createStrigaUserFor(int appUserId, String accessToken) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'striga/create-user',
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
        body: {
          'userId': appUserId,
        },
      );

      final data = response.data;

      if (data['isRequestSuccessfull'] != true) {
        print('Striga create-user failed: ${data['error']}');
      } else {
        print('Striga user created successfully');
      }
    } catch (e) {
      print('Error calling striga/create-user: $e');
    }
  }
}
