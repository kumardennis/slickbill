import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../getx_controllers/user_controller.dart';
import '../models/user_model.dart';

JsonEncoder encoder = const JsonEncoder.withIndent('  ');

class SupabaseAuthManger {
  final supabseClient = Supabase.instance.client;
  final userController = Get.put(UserController());

  Future<void> loadFreshUser(authUserId, accessToken) async {
    final tokenToUse = accessToken;

    print('TOKEN IN USE: $tokenToUse');

    final userRecordResponse = await supabseClient
        .from('users')
        .select('*')
        .eq('authUserId', authUserId);

    final userProfileClassed = UserModel(
      userRecordResponse[0]['id'],
      userRecordResponse[0]['username'],
      userRecordResponse[0]['email'],
      userRecordResponse[0]['authUserId'],
      tokenToUse,
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

    final clientUserClassed = ClientUserModel(
      userRecordResponse[0]['id'],
      privateUserResponse.length > 0 ? privateUserResponse[0]['id'] : null,
      businessUserResponse.length > 0 ? businessUserResponse[0]['id'] : null,
      userRecordResponse[0]['username'],
      userRecordResponse[0]['email'],
      userRecordResponse[0]['authUserId'],
      tokenToUse,
      privateUserResponse.length > 0
          ? privateUserResponse[0]['iban']
          : businessUserResponse[0]['iban'],
      privateUserResponse.length > 0
          ? privateUserResponse[0]['bankAccountName']
          : businessUserResponse[0]['bankAccountName'],
      privateUserResponse.length > 0
          ? privateUserResponse[0]['firstName']
          : null,
      privateUserResponse.length > 0
          ? privateUserResponse[0]['lastName']
          : null,
      businessUserResponse.length > 0
          ? businessUserResponse[0]['fullName']
          : null,
      businessUserResponse.length > 0
          ? businessUserResponse[0]['publicName']
          : null,
      privateUserResponse.length > 0,
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

  Future<void> signUp(
      String email,
      String password,
      String firstNanme,
      String lastName,
      String username,
      String iban,
      String accountHolder) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('auth-and-settings/create-user', headers: {
        'Authorization': 'Bearer ${dotenv.env['SUPABASE_ANON_LOCAL_KEY']}'
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
}
