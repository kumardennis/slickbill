import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:slickbill/_NFCHandler.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/config/env_config.dart';
import 'package:slickbill/feature_auth/screens/home_screen.dart';
import 'package:slickbill/feature_auth/screens/sign_up.dart';
import 'package:slickbill/feature_auth/screens/spash_screen.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:slickbill/feature_public/screens/public_invoice_landing.dart';
import 'package:slickbill/feature_public/screens/public_invoice_view.dart';
import 'package:slickbill/shared_locales/locale_en.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feature_auth/screens/sign_in.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env for local development
  if (kDebugMode) {
    await dotenv.load();
  }

  print('🔍 Initializing Supabase...');
  print('🔍 Is Debug Mode: $kDebugMode');
  print('🔍 Supabase Key present: ${EnvConfig.supabaseAnonKey.isNotEmpty}');

  await Supabase.initialize(
    url: 'https://fwujdruuvspdoqflttrl.supabase.co',
    anonKey: EnvConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  print('✅ Supabase initialized');

  Get.put<UserController>(UserController(), permanent: true);
  Get.put<DigitalInvoiceController>(DigitalInvoiceController(),
      permanent: true);
  Get.put<NavigationController>(NavigationController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return NFCHandlerWidget(
      child: GlobalLoaderOverlay(
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: MyCustomScrollBehavior(),
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          title: 'SlickBill',
          theme: ThemeData(
            scaffoldBackgroundColor: Color(0xFFF5F5F5),
            primarySwatch: Colors.blue,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Color(0xFF1E3A8A),
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.robotoTextTheme(
              const TextTheme(
                displayLarge: TextStyle(fontSize: 24.0, color: Colors.white),
                displayMedium: TextStyle(fontSize: 20.0, color: Colors.white),
                displaySmall: TextStyle(fontSize: 16.0, color: Colors.white),
                bodyLarge: TextStyle(fontSize: 20, color: Colors.white),
                bodyMedium: TextStyle(fontSize: 16.0, color: Colors.white),
                bodySmall: TextStyle(fontSize: 12.0, color: Colors.white),
                headlineLarge: TextStyle(fontSize: 32, color: Colors.white),
                headlineMedium: TextStyle(fontSize: 24.0, color: Colors.white),
                headlineSmall: TextStyle(fontSize: 18.0, color: Colors.white),
              ),
            ),
          ),
          home: const SplashScreen(),
          initialRoute: '/splash',
          getPages: [
            GetPage(name: '/splash', page: () => const SplashScreen()),
            GetPage(name: '/sign-up', page: () => SignUp()),
            GetPage(name: '/sign-in', page: () => const SignIn()),
            GetPage(name: '/home-screen', page: () => HomeScreen()),
            GetPage(
              name: '/public-invoice-view',
              page: () => PublicInvoiceView(
                token: Get.arguments['token'] ?? '',
              ),
            ),
            GetPage(
              name: '/bill/:token',
              page: () => PublicInvoiceLanding(
                token: Get.parameters['token'] ?? '',
              ),
            ),
            GetPage(
              name: '/',
              page: () => const SplashScreen(),
            ),
          ],
        ),
      ),
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}
