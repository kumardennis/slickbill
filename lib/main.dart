import 'dart:async';
import 'package:flutter/foundation.dart';
// Conditionally import app_links
import 'package:app_links/app_links.dart'
    if (dart.library.html) 'package:slickbill/mock_app_links.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:slickbill/_NFCHandler.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/config/env_config.dart';
import 'package:slickbill/core/services/push_notification_service.dart';
import 'package:slickbill/feature_auth/screens/home_screen.dart';
import 'package:slickbill/feature_auth/screens/sign_up.dart';
import 'package:slickbill/feature_auth/screens/spash_screen.dart';
import 'package:slickbill/feature_auth/services/deep_links.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_navigation/getx_controllers/navigation_controller.dart';
import 'package:slickbill/feature_public/screens/public_invoice_landing.dart';
import 'package:slickbill/feature_public/screens/public_invoice_view.dart';
import 'package:slickbill/shared_locales/locale_en.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feature_auth/screens/sign_in.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // add this import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use path-based URLs on web (no #)
  usePathUrlStrategy();

  // Load .env for local development

  if (kDebugMode) {
    try {
      await dotenv.load();
      print('✅ dotenv loaded');
    } catch (e, st) {
      print('⚠️ dotenv load failed: $e');
      print(st);
    }
  }
  await dotenv.load();

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

  // ✅ Initialize OneSignal app (once at startup)
  await PushNotificationService.initializeApp();

  Get.put<UserController>(UserController(), permanent: true);
  Get.put<DigitalInvoiceController>(DigitalInvoiceController(),
      permanent: true);
  Get.put<NavigationController>(NavigationController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// Parse browser URL into a valid GetX route name
  String _getInitialRoute() {
    if (!kIsWeb) {
      return '/splash';
    }

    final path = Uri.base.path;
    print('🌐 Raw browser path: $path');

    // Handle /bill/<token>
    if (path.startsWith('/bill/')) {
      final token = path.replaceFirst('/bill/', '');
      if (token.isNotEmpty) {
        print('🌐 Parsed bill token: $token');
        Get.parameters['token'] = token;
        return '/bill/:token';
      }
    }

    // Handle /home-screen, /sign-in, etc.
    if (path.isNotEmpty && path != '/') {
      print('🌐 Using path as-is: $path');
      return path;
    }

    // Default
    return '/splash';
  }

  Future<void> _handleInitialLink() async {
    final appLinks = AppLinks();

    // Handle app opened from deep link (when app was closed)
    final initialUri = await appLinks.getInitialLink();

    if (initialUri != null) {
      print('🔗 Initial deep link: $initialUri');
      // The uriLinkStream will handle it, so we just log here
    }
  }

  @override
  void initState() {
    super.initState();
    _handleInitialLink(); // ✅ Add this
    deepLinkHandler(context);
    print('🌐 MyApp initialized');
  }

  @override
  Widget build(BuildContext context) {
    final initialRoute = _getInitialRoute();
    print('🌐 Resolved initialRoute: $initialRoute');

    return NFCHandlerWidget(
      child: GlobalLoaderOverlay(
        child: GetMaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: MyCustomScrollBehavior(),
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          title: 'SlickBill',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E3A8A),
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

          // Use the pre-parsed route
          initialRoute: initialRoute,

          getPages: [
            GetPage(name: '/splash', page: () => const SplashScreen()),
            GetPage(name: '/sign-up', page: () => SignUp()),
            GetPage(
              name: '/sign-in',
              page: () => SignIn(
                invoice_token: Get.parameters['invoice_token'],
              ),
            ),
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

          routingCallback: (routing) {
            print(
                '🔍 ROUTE CHANGE: ${routing?.current} <- ${routing?.previous}');
            print('   Stack trace: ${StackTrace.current}');
          },

          unknownRoute: GetPage(
            name: '/404',
            page: () {
              if (kIsWeb) {
                print('❌ Unknown route: ${Uri.base.path}');
                // Redirect to splash after a brief delay
                Future.delayed(const Duration(milliseconds: 100), () {
                  Get.offNamed('/splash');
                });
              }
              return const SplashScreen();
            },
          ),
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
