import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void deepLinkHandler(BuildContext context) {
  final appLinks = AppLinks();
  String? lastProcessedLink;

  final sub = appLinks.uriLinkStream.listen((Uri? uri) {
    if (uri != null) {
      print('🔗 Received deep link: $uri');
      final uriString = uri.toString();
      // Prevent duplicate processing
      if (lastProcessedLink == uriString) {
        print('⏭️ Skipping duplicate deep link: $uriString');
        return;
      }

      if (uri.scheme == 'slickbills' && uri.host == 'bill') {
        print('📄 Bill deep link detected');

        if (uri.pathSegments.isNotEmpty) {
          // Has invoice token: slickbills://bill/invoice-token
          final invoiceToken = uri.pathSegments[0];
          print('   Invoice token: $invoiceToken');
          Get.offAllNamed('/bill/$invoiceToken');
        } else {
          // No token: slickbills://bill
          print('   No invoice token, going to bills list');
          Get.toNamed('/home-screen'); // or wherever you list bills
        }
        return;
      }

      // ✅ Handle HTTPS deep links (for web)
      if (uri.scheme == 'https' && uri.host == 'slickbills.com') {
        if (uri.pathSegments.isNotEmpty) {
          print('🌐 Web deep link: /${uri.pathSegments.join('/')}');
          Get.toNamed('/${uri.pathSegments.join('/')}');
        }
        return;
      }

      // ✅ Check if it's an OAuth callback
      if (uri.scheme == 'slickbills' && uri.host == 'home-screen') {
        print('🔵 Facebook OAuth callback detected');

        // Supabase will automatically handle the callback
        // The session will be available via supabase.auth.currentSession

        // Give it a moment to process
        Future.delayed(Duration(milliseconds: 500), () {
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            print('✅ OAuth session established');
            // Navigation will be handled by SupabaseAuthManger
          } else {
            print('⚠️ No session found after OAuth callback');
          }
        });

        return;
      }
    }
  }, onError: (err) {
    print('❌ Error receiving deep link: $err');
  });
}
