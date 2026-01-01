import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/screens/home_screen.dart';
import 'package:slickbill/feature_auth/services/google_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/supabase_auth_manger.dart';

class SignIn extends HookWidget {
  const SignIn({super.key});

  @override
  Widget build(BuildContext context) {
    UserController userController = Get.find<UserController>();
    final SupabaseAuthManger _supabase = SupabaseAuthManger();
    final GoogleAuthService _googleAuthService = GoogleAuthService();

    TextEditingController? textController1 = useTextEditingController();
    TextEditingController? textController2 = useTextEditingController();

    useEffect(() {
      getStoredCredentials() async {
        final prefs = await SharedPreferences.getInstance();

        final String? storedEmail = prefs.getString('email');

        final String? storedPassword = prefs.getString('password');

        if (storedEmail != null) textController1.text = storedEmail;

        if (storedPassword != null) textController2.text = storedPassword;

        if (storedEmail != null && storedPassword != null) {
          // await _supabase.signIn(storedEmail, storedPassword);
        }

        if (storedPassword != null) textController2.text = storedPassword;
      }

      getStoredCredentials();
      return null;
    }, []);

    void signIn() async {
      await _supabase.signIn(textController1.text, textController2.text);

      // After successful sign in
      if (Get.arguments != null && Get.arguments['returnUrl'] != null) {
        Get.offAllNamed(Get.arguments['returnUrl']);
      } else {
        Get.offAllNamed('/home-screen');
      }
    }

    Future<void> handleGoogleSignIn() async {
      try {
        if (kIsWeb) {
          print('🌐 Initiating Google Sign-In for web...');
          await _googleAuthService.signInWithGoogleWeb();
          // Code after this won't execute because browser redirects
          return;
        }

        // Mobile flow - show loading dialog
        Get.dialog(
          const Center(child: CircularProgressIndicator()),
          barrierDismissible: false,
        );

        final success = await _supabase.signInWithGoogle();

        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        if (success) {
          Get.offAll(() => HomeScreen());
          Get.snackbar(
            'Success',
            'Signed in with Google successfully',
            backgroundColor: Colors.green.withOpacity(0.1),
            colorText: Colors.green,
            duration: Duration(seconds: 2),
          );
        } else {
          Get.snackbar(
            'Error',
            'Google Sign-In was cancelled or failed',
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
            duration: Duration(seconds: 3),
          );
        }
      } catch (e) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }

        Get.snackbar(
          'Error',
          'Failed to sign in with Google: ${e.toString()}',
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
          duration: Duration(seconds: 3),
        );
      }
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: MediaQuery.of(context).size.height),
            child: Container(
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                Theme.of(context).colorScheme.blue,
                Theme.of(context).colorScheme.dark,
                Theme.of(context).colorScheme.dark
              ], begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Align(
                  alignment: const AlignmentDirectional(0, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: const BoxDecoration(
                            color: Color.fromARGB(0, 233, 20, 20)),
                        child: Align(
                          alignment: const AlignmentDirectional(0, 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                            child: Image.asset('assets/logo_text_darkbg.png'),
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: 211,
                        decoration: const BoxDecoration(
                          color: Color(0x00FFFFFF),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Flexible(
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                height: 60,
                                child: TextFormField(
                                  controller: textController1,
                                  onChanged: (value) {},
                                  autofocus: true,
                                  obscureText: false,
                                  decoration: InputDecoration(
                                    labelStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .light),
                                    labelText: 'lbl_Username'.tr,
                                    hintStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .light),
                                    enabledBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFFE0F2F1),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(4.0),
                                        topRight: Radius.circular(4.0),
                                      ),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFFE0F2F1),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(4.0),
                                        topRight: Radius.circular(4.0),
                                      ),
                                    ),
                                    errorBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0x00000000),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(4.0),
                                        topRight: Radius.circular(4.0),
                                      ),
                                    ),
                                    focusedErrorBorder:
                                        const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0x00000000),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(4.0),
                                        topRight: Radius.circular(4.0),
                                      ),
                                    ),
                                    suffixIcon: InkWell(
                                      onTap: () async {
                                        textController1.clear();
                                      },
                                      child: Icon(
                                        Icons.clear,
                                        color:
                                            Theme.of(context).colorScheme.light,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.light,
                                      ),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            ),
                            Flexible(
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width * 0.7,
                                height: 60,
                                child: TextFormField(
                                  controller: textController2,
                                  onChanged: (value) {},
                                  autofocus: true,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'lbl_Password'.tr,
                                    labelStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .light),
                                    hintStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .light),
                                    enabledBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFFE0F2F1),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(4.0),
                                        topRight: Radius.circular(4.0),
                                      ),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0xFFE0F2F1),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(4.0),
                                        topRight: Radius.circular(4.0),
                                      ),
                                    ),
                                    errorBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0x00000000),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(4.0),
                                        topRight: Radius.circular(4.0),
                                      ),
                                    ),
                                    focusedErrorBorder:
                                        const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0x00000000),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(4.0),
                                        topRight: Radius.circular(4.0),
                                      ),
                                    ),
                                    suffixIcon: InkWell(
                                      onTap: () async {
                                        textController2.clear();
                                      },
                                      child: Icon(
                                        Icons.clear,
                                        color:
                                            Theme.of(context).colorScheme.light,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.light,
                                      ),
                                  textAlign: TextAlign.start,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.5,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: Color(0x00FFFFFF),
                        ),
                        child: ElevatedButton(
                          onPressed: signIn,
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.blue,
                              elevation: 5,
                              fixedSize: const Size(100, 70)),
                          child: Text(
                            'btn_SignIn'.tr,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.light),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Row(
                          children: [
                            Expanded(
                                child: Divider(
                                    color: Theme.of(context).colorScheme.gray)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.gray,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                                child: Divider(
                                    color: Theme.of(context).colorScheme.gray)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: ElevatedButton(
                          onPressed: handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png',
                                height: 24,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.g_mobiledata, size: 24);
                                },
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        child: Text(
                          'lbl_GoToSignUp'.tr,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        onTap: () {
                          Get.toNamed('/sign-up');
                        },
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
