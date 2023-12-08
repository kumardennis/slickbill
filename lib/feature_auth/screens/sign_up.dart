import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/shared_widgets/input_field.dart';

import '../utils/supabase_auth_manger.dart';

class SignUp extends HookWidget {
  SignUp({Key? key}) : super(key: key);

  final _supabase = SupabaseAuthManger();

  @override
  Widget build(BuildContext context) {
    TextEditingController? email = useTextEditingController();
    TextEditingController? password = useTextEditingController();
    TextEditingController? confirmPassword = useTextEditingController();
    TextEditingController? firstName = useTextEditingController();
    TextEditingController? lastName = useTextEditingController();
    TextEditingController? username = useTextEditingController();
    TextEditingController? iban = useTextEditingController();
    TextEditingController? accountHolder = useTextEditingController();

    void signIn() async {
      if (password.text != confirmPassword.text) {
        Get.snackbar('Ooops..', 'Passwords not matching');
        return;
      }
      if (username.text == '') {
        Get.snackbar('Ooops..', 'Username is kinda important');
        return;
      }
      if (iban.text == '' || accountHolder.text == '') {
        Get.snackbar('Ooops..', 'Please add your shareable bank info...');
        return;
      }
      await _supabase.signUp(email.text, password.text, firstName.text,
          lastName.text, username.text, iban.text, accountHolder.text);
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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
                      height: 180,
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(0, 233, 20, 20),
                      ),
                      child: Align(
                        alignment: const AlignmentDirectional(0, 0),
                        child: Stack(
                          children: [
                            Image.asset('media/temporary_logo.png'),
                            Positioned(
                              child:
                                  Image.asset('media/temporary_logo_text.png'),
                              top: 120.0,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 311,
                      decoration: const BoxDecoration(
                        color: Color(0x00FFFFFF),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            InputField(
                              controller: email,
                              label: 'lbl_Email'.tr,
                              obscure: false,
                            ),
                            InputField(
                              controller: password,
                              label: 'lbl_Password'.tr,
                              obscure: true,
                            ),
                            InputField(
                                controller: confirmPassword,
                                label: 'lbl_ConfirmPassword'.tr,
                                obscure: true),
                            InputField(
                                controller: firstName,
                                label: 'lbl_FirstName'.tr,
                                obscure: false),
                            InputField(
                                controller: lastName,
                                label: 'lbl_LastName'.tr,
                                obscure: false),
                            InputField(
                                controller: username,
                                label: 'lbl_Username'.tr,
                                obscure: false),
                            InputField(
                                controller: iban,
                                label: 'lbl_IBAN'.tr,
                                obscure: false),
                            InputField(
                                controller: accountHolder,
                                label: 'lbl_AccountHolder'.tr,
                                obscure: false),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 40,
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
                            primary: Theme.of(context).colorScheme.blue,
                            elevation: 5,
                            fixedSize: const Size(100, 70)),
                        child: Text(
                          'btn_SignUp'.tr,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.light),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 40,
                    ),

                    GestureDetector(
                      child: Text(
                        'lbl_GoToSignIn'.tr,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      onTap: () {
                        Get.toNamed('/sign-in');
                      },
                    )
                    // Padding(
                    //   padding: const EdgeInsets.all(10.0),
                    //   child: SocialLoginButton(
                    //     buttonType: SocialLoginButtonType.facebook,
                    //     onPressed: () {
                    //       signIn();
                    //     },
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
