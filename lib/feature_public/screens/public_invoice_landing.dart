import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_public/models/public_invoice_model.dart';
import 'package:slickbill/feature_public/screens/public_invoice_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class PublicInvoiceLanding extends HookWidget {
  final String token;

  const PublicInvoiceLanding({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final invoiceController = Get.find<DigitalInvoiceController>();
    final userController = Get.find<UserController>();
    final _supabaseAuthManager = SupabaseAuthManger();

    final invoice = useState<PublicInvoiceModel?>(null);
    final isLoading = useState<bool>(true);
    final hasCheckedDeepLink = useState<bool>(false);

    Future<void> _checkAuth() async {
      await Future.delayed(const Duration(seconds: 2));

      // Check for OAuth errors in URL (web only)
      if (kIsWeb) {
        final uri = Uri.base;
        final error = uri.queryParameters['error'];
        final errorDescription = uri.queryParameters['error_description'];

        if (error != null) {
          print('❌ OAuth error in URL: $error - $errorDescription');
          await Future.delayed(Duration(milliseconds: 100));
        }
      }

      final session = Supabase.instance.client.auth.currentSession;

      print('🔍 Splash: Session exists: ${session != null}');
      if (session != null) {
        print('🔍 Auth User ID: ${session.user.id}');
        print('🔍 Auth User Email: ${session.user.email}');
        print('🔍 Access Token present: ${session.accessToken.isNotEmpty}');
      }

      if (context.mounted) {
        if (session != null) {
          print('✅ Splash: active session found, fetching user from DB');

          try {
            // Use SupabaseAuthManager to get user
            await _supabaseAuthManager.loadFreshUser(
                session.user.id, session.accessToken);

            print('🔍 User fetched: ${userController.user.value.email}');
            print(
                '🔍 User privateUserId: ${userController.user.value.privateUserId}');

            if (userController.user != null) {
              print('✅ User data loaded: ${userController.user.value.email}');

              print('✅ User data and invoices loaded, navigating to home');
            } else {
              print('❌ User not found or privateUserId is null');
              await Supabase.instance.client.auth.signOut();
              Get.offAllNamed('/sign-in');

              Future.delayed(Duration(milliseconds: 300), () {
                Get.snackbar(
                  'Error',
                  'Failed to load user profile. Please sign in again.',
                  backgroundColor: Colors.red.withOpacity(0.1),
                  colorText: Colors.red,
                );
              });
            }
          } catch (e) {
            print('❌ Error fetching user: $e');
            await Supabase.instance.client.auth.signOut();
            Get.offAllNamed('/sign-in');

            Future.delayed(Duration(milliseconds: 300), () {
              Get.snackbar(
                'Error',
                'Error loading user: ${e.toString()}',
                backgroundColor: Colors.red.withOpacity(0.1),
                colorText: Colors.red,
              );
            });
          }
        }
      }
    }

    useEffect(() {
      Future<void> initialize() async {
        // Load the invoice first
        try {
          final loadedInvoice =
              await invoiceController.getPublicInvoiceByToken(token);
          invoice.value = loadedInvoice;

          await _checkAuth();

          // If on web, try to open in app
          if (kIsWeb && !hasCheckedDeepLink.value) {
            hasCheckedDeepLink.value = true;
            _tryOpenInApp(token, context);
          }
        } catch (e) {
          Get.snackbar('Error', 'Failed to load invoice: $e');
        } finally {
          isLoading.value = false;
        }
      }

      initialize();
      return null;
    }, []);

    // If on mobile/app, go directly to the full view
    if (!kIsWeb) {
      return PublicInvoiceView(token: token);
    }

    // Web view with app detection
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.light,
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: isLoading.value
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.blue,
                ),
              )
            : invoice.value == null
                ? _buildErrorView(context)
                : _buildWebView(context, invoice.value!, userController),
      ),
    );
  }

  void _tryOpenInApp(String token, BuildContext context) {
    // Try to open in app
    final deepLink = 'slickbill://bill/$token';
    final webFallback = 'https://slickbills-app.vercel.app/#/bill/$token';

    // Attempt deep link
    html.window.location.href = deepLink;

    // Show dialog after short delay
    Future.delayed(Duration(milliseconds: 500), () {
      // ... rest of dialog code
    });
  }

  void _showAppInstallDialog(
      BuildContext context, String appStoreLink, String playStoreLink) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Open in SlickBills App?',
          style: TextStyle(color: Theme.of(context).colorScheme.dark),
        ),
        content: Text(
          'For the best experience, open this invoice in the SlickBills mobile app.',
          style: TextStyle(color: Theme.of(context).colorScheme.darkGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Continue on Web'),
          ),
          ElevatedButton(
            onPressed: () {
              // Detect platform and open appropriate store
              final userAgent = html.window.navigator.userAgent.toLowerCase();
              if (userAgent.contains('iphone') || userAgent.contains('ipad')) {
                html.window.open(appStoreLink, '_blank');
              } else {
                html.window.open(playStoreLink, '_blank');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.blue,
            ),
            child: Text('Download App',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.light,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.red,
          ),
          SizedBox(height: 16),
          Text(
            'Invoice Not Found',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.dark,
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: 8),
          Text(
            'This invoice link may be invalid or expired',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.darkGray,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView(BuildContext context, PublicInvoiceModel invoice,
      UserController userController) {
    final isLoggedIn = userController.user.value.privateUserId != null;
    bool dateIsPassed = invoice.deadline != null &&
        DateTime.now().isAfter(DateTime.parse(invoice.deadline!));

    final _digitalInvoiceController = Get.find<DigitalInvoiceController>();

    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.darkerBlue,
            Theme.of(context).colorScheme.blue,
            Theme.of(context).colorScheme.turqouise,
            Theme.of(context).colorScheme.darkerBlue,
          ],
          stops: const [0.0, 0.2, 0.7, 0.85],
          transform: GradientRotation(3.14 / 4),
          tileMode: TileMode.clamp,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 600),
              padding: EdgeInsets.all(24),
              // Add min height to ensure content fills screen
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with Status and Amount
                    Container(
                      padding: EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Invoice',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.dark,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: invoice.status == 'PAID'
                                      ? Theme.of(context)
                                          .colorScheme
                                          .green
                                          .withOpacity(0.15)
                                      : dateIsPassed
                                          ? Theme.of(context)
                                              .colorScheme
                                              .red
                                              .withOpacity(0.15)
                                          : Theme.of(context)
                                              .colorScheme
                                              .yellow
                                              .withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Text(
                                  invoice.status == 'PAID' ? 'PAID' : 'UNPAID',
                                  style: TextStyle(
                                    color: invoice.status == 'PAID'
                                        ? Theme.of(context).colorScheme.green
                                        : dateIsPassed
                                            ? Theme.of(context).colorScheme.red
                                            : Theme.of(context)
                                                .colorScheme
                                                .yellow,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Text(
                            '€${invoice.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.blue,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          if (invoice.description != null) ...[
                            SizedBox(height: 12),
                            Text(
                              invoice.description!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.dark,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Invoice Details Card
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice Details',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.dark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          if (invoice.senderName != null)
                            _buildDetailRow(
                              context,
                              'From',
                              invoice.senderName!,
                              copyable: true, // Enable copy
                            ),
                          if (invoice.senderIban != null)
                            _buildDetailRow(
                              context,
                              'IBAN',
                              invoice.senderIban!,
                              copyable: true, // Enable copy
                            ),
                          if (invoice.category != null)
                            _buildDetailRow(
                              context,
                              'Category',
                              invoice.category!,
                            ),
                          if (invoice.referenceNo != null &&
                              invoice.referenceNo!.isNotEmpty)
                            _buildDetailRow(
                              context,
                              'Reference',
                              invoice.referenceNo!,
                              copyable: true, // Enable copy
                            ),
                          if (invoice.deadline != null)
                            _buildDetailRow(
                              context,
                              'Due Date',
                              DateFormat('EEE, dd MMM yyyy').format(
                                DateTime.parse(invoice.deadline!),
                              ),
                              highlight: dateIsPassed,
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32),

                    // Action Buttons
                    if (isLoggedIn) ...[
                      // User is logged in - show Claim button
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            final claimedInvoice =
                                await _digitalInvoiceController
                                    .claimPublicInvoice(
                              token: token,
                              claimerUserId: userController.user.value.id!,
                              claimerPrivateUserId:
                                  userController.user.value.privateUserId!,
                            );

                            if (claimedInvoice != null) {
                              Get.snackbar(
                                'Success',
                                'Invoice claimed successfully!',
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .green
                                    .withOpacity(0.2),
                                colorText: Theme.of(context).colorScheme.green,
                              );

                              Future.delayed(Duration(seconds: 1), () {
                                Get.offAllNamed('/home-screen');
                              });
                            }
                          } catch (e) {
                            Get.snackbar(
                              'Error',
                              e.toString(),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .red
                                  .withOpacity(0.2),
                              colorText: Theme.of(context).colorScheme.red,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 18),
                          elevation: 8,
                          shadowColor: Theme.of(context)
                              .colorScheme
                              .blue
                              .withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Claim This Invoice',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: () {
                          Get.to(() => PublicInvoiceView(token: token));
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white, width: 2),
                          padding: EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'View Full Details',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ] else ...[
                      // User is not logged in - show Sign Up buttons
                      ElevatedButton(
                        onPressed: () {
                          Get.toNamed('/sign-up');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 18),
                          elevation: 8,
                          shadowColor: Theme.of(context)
                              .colorScheme
                              .blue
                              .withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Sign Up to Claim Invoice',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      TextButton(
                        onPressed: () {
                          // Save the current route to return after sign in
                          Get.toNamed('/sign-in',
                              arguments: {'returnUrl': '/bill/$token'});
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Already have an account? Sign In',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
    bool copyable = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.darkGray,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: highlight
                          ? Theme.of(context).colorScheme.red
                          : Theme.of(context).colorScheme.dark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                if (copyable) ...[
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      Get.snackbar(
                        'Copied!',
                        '$label copied to clipboard',
                        backgroundColor:
                            Theme.of(context).colorScheme.blue.withOpacity(0.2),
                        colorText: Theme.of(context).colorScheme.blue,
                        duration: Duration(seconds: 2),
                        snackPosition: SnackPosition.BOTTOM,
                        margin: EdgeInsets.all(16),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: Theme.of(context).colorScheme.blue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
