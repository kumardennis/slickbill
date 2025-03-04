import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:slickbill/_NFCHandler.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/screens/home_screen.dart';
import 'package:slickbill/feature_auth/screens/sign_up.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:slickbill/shared_locales/locale_en.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'feature_auth/screens/sign_in.dart';

void main() async {
  final localDBUrl = 'http://192.168.1.3:44321';
  final remoteDDUrl = 'https://fwujdruuvspdoqflttrl.supabase.co';

  await dotenv.load();
  await Supabase.initialize(
      url: localDBUrl, anonKey: dotenv.env['SUPABASE_ANON_LOCAL_KEY'] ?? '');
  // Get.put(NavigationController());
  runApp(MyApp(
    home: SignIn(),
  ));
}

class MyApp extends StatelessWidget {
  MyApp({@required this.home});
  final home;

  NavigationController navigationController = Get.put(NavigationController());

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return NFCHandlerWidget(
      child: GetMaterialApp(
        scrollBehavior: MyCustomScrollBehavior(),
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        title: 'Flutter Demo',
        theme: ThemeData(
            scaffoldBackgroundColor: Theme.of(context).colorScheme.light,
            primarySwatch: Colors.blue,
            textTheme: GoogleFonts.robotoTextTheme(TextTheme(
                displayLarge: TextStyle(
                    fontSize: 24.0, color: Theme.of(context).colorScheme.light),
                displayMedium: TextStyle(
                    fontSize: 20.0, color: Theme.of(context).colorScheme.light),
                displaySmall: TextStyle(
                    fontSize: 16.0, color: Theme.of(context).colorScheme.light),
                bodyLarge: TextStyle(
                    fontSize: 20, color: Theme.of(context).colorScheme.light),
                bodyMedium: TextStyle(
                    fontSize: 16.0, color: Theme.of(context).colorScheme.light),
                bodySmall: TextStyle(
                    fontSize: 12.0, color: Theme.of(context).colorScheme.light),
                headlineLarge: TextStyle(
                    fontSize: 32, color: Theme.of(context).colorScheme.light),
                headlineMedium: TextStyle(
                    fontSize: 24.0, color: Theme.of(context).colorScheme.light),
                headlineSmall: TextStyle(
                    fontSize: 18.0,
                    color: Theme.of(context).colorScheme.light)))),
        home: home,
        initialRoute: '/sign-in',
        getPages: [
          GetPage(name: '/sign-up', page: () => SignUp()),
          GetPage(name: '/sign-in', page: () => SignIn()),
          GetPage(name: '/home-screen', page: () => HomeScreen()),
        ],
      ),
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        // etc.
      };
}
