import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slickbill/color_scheme.dart';

import '../utils/supabase_auth_manger.dart';

class SignIn extends HookWidget {
  SignIn({Key? key}) : super(key: key);

  final _supabase = SupabaseAuthManger();

  @override
  Widget build(BuildContext context) {
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
    }

    return Scaffold(
      body: SafeArea(
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
                    height: 300,
                    decoration: const BoxDecoration(
                        color: Color.fromARGB(0, 233, 20, 20)),
                    child: Align(
                      alignment: const AlignmentDirectional(0, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                        child: Image.asset('media/logo blue.webp'),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 111,
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
                                    color: Theme.of(context).colorScheme.light),
                                labelText: 'lbl_Username'.tr,
                                hintStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.light),
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
                                focusedErrorBorder: const UnderlineInputBorder(
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
                                    color: Theme.of(context).colorScheme.light,
                                    size: 22,
                                  ),
                                ),
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyText1
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.light,
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
                                    color: Theme.of(context).colorScheme.light),
                                hintStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.light),
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
                                focusedErrorBorder: const UnderlineInputBorder(
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
                                    color: Theme.of(context).colorScheme.light,
                                    size: 22,
                                  ),
                                ),
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyText1
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.light,
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
                          primary: Theme.of(context).colorScheme.blue,
                          elevation: 5,
                          fixedSize: const Size(100, 70)),
                      child: Text(
                        'btn_SignIn'.tr,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.light),
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
    );
  }
}
