import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slickbill/feature_auth/screens/sign_in.dart';
import 'package:slickbill/feature_auth/services/google_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class UserController extends GetxController {
  final supabase = Supabase.instance.client;
  var user = ClientUserModel(
    id: 0,
    username: '',
    email: '',
    authUserId: '',
    accessToken: '',
    isPrivate: true,
    firstName: '',
    lastName: '',
  ).obs;

  var _isRefreshing = false;
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  loadUser(ClientUserModel updatedUser) {
    user.value = updatedUser;
    saveUserData();
  }

  bool _isTokenExpired(Session session) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    return session.expiresAt != null && session.expiresAt! <= now;
  }

  Future<bool> refreshSessionIfNeeded() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return false;

      if (_isTokenExpired(session)) {
        print('Token expired, attempting refresh...');
        final response = await supabase.auth.refreshSession();

        if (response.session != null) {
          // Update the access token in user model
          user.value = user.value.copyWith(
            accessToken: response.session!.accessToken,
          );
          await saveUserData();
          print('Session refreshed successfully');
          return true;
        } else {
          print('Failed to refresh session');
          await clearUserData();
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error refreshing session: $e');
      await clearUserData();
      return false;
    }
  }

  Future<void> saveUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.value.toJson());
      await prefs.setString('user_data', userJson);
      print('User data saved to local storage');
    } catch (e) {
      print('Error saving user data: $e');
    }
  }

  Future<bool> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_data');

      if (userJson != null) {
        final userData = jsonDecode(userJson);
        user.value = ClientUserModel.fromJson(userData);

        // Validate the session
        final session = supabase.auth.currentSession;
        if (session != null && !_isTokenExpired(session)) {
          print('User data loaded and session is valid');
          return true;
        } else {
          print('Session is expired or invalid');
          await clearUserData();
          return false;
        }
      }
      return false;
    } catch (e) {
      print('Error loading user data: $e');
      await clearUserData();
      return false;
    }
  }

  Future<void> clearUserData() async {
    try {
      await _googleAuthService.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');
      user.value = ClientUserModel(
        id: 0,
        username: '',
        email: '',
        authUserId: '',
        accessToken: '',
        isPrivate: true,
        firstName: '',
        lastName: '',
      );
      print('User data cleared');
    } catch (e) {
      print('Error clearing user data: $e');
    }
  }

  Future<void> forceLogout() async {
    try {
      await supabase.auth.signOut();
      await clearUserData();
      Get.offAll(() => SignIn());
    } catch (e) {
      print('Error during force logout: $e');
    }
  }
}
