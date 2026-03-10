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
import 'package:url_launcher/url_launcher.dart';

class PublicInvoiceLanding extends HookWidget {
  final String token;

  const PublicInvoiceLanding({super.key, required this.token});

  List<String> _extractUrls(String text) {
    final urlPattern = RegExp(
      r'(https?:\/\/[^\s]+)|(www\.[^\s]+)|([a-zA-Z0-9-]+\.(com|net|org|io|me|app|co)[^\s]*)',
      caseSensitive: false,
    );
    final matches = urlPattern.allMatches(text);
    return matches.map((match) => match.group(0)!).toList();
  }

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
          await Future.delayed(const Duration(milliseconds: 100));
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

              Future.delayed(const Duration(milliseconds: 300), () {
                Get.snackbar(
                  'Error',
                  'Failed to load user profile. Please sign in again.',
                  backgroundColor: Theme.of(context).colorScheme.red,
                  colorText: Colors.white,
                );
              });
            }
          } catch (e) {
            print('❌ Error fetching user: $e');
            await Supabase.instance.client.auth.signOut();
            Get.offAllNamed('/sign-in');

            Future.delayed(const Duration(milliseconds: 300), () {
              Get.snackbar(
                'Error',
                'Error loading user: ${e.toString()}',
                backgroundColor: Theme.of(context).colorScheme.red,
                colorText: Colors.white,
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

          // ✅ Check if widget is still mounted before updating state
          if (!context.mounted) return;

          invoice.value = loadedInvoice;

          await invoiceController.trackPublicInvoiceView(token);

          await _checkAuth();

          // If on web, try to open in app
          if (kIsWeb && !hasCheckedDeepLink.value) {
            hasCheckedDeepLink.value = true;
          }
        } catch (e) {
          // ✅ Check if widget is still mounted before showing snackbar
          if (!context.mounted) return;

          Get.snackbar('Error', 'Failed to load invoice: $e');

          print('❌ Error loading public invoice: $token $e');
        } finally {
          // ✅ Only update if widget is still mounted
          if (context.mounted) {
            isLoading.value = false;
          }
        }
      }

      initialize();

      // ✅ Add cleanup function
      return () {
        // Cleanup when widget is disposed
        print('🧹 PublicInvoiceLanding disposed');
      };
    }, []); // Keep empty dependency array

    // If on mobile/app, go directly to the full view
    // if (!kIsWeb) {
    //   return PublicInvoiceView(token: token);
    // }

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

  void _showAppInstallDialog(BuildContext context, String token) {
    // With Universal Links, you use the standard HTTPS URL.
    // The OS will open the app if it's installed, or the website if it's not.
    final universalLink = 'slickbills://bill/$token';

    Get.dialog(
      AlertDialog(
        title: Text(
          'Open in SlickBill App?',
          style: TextStyle(color: Theme.of(context).colorScheme.dark),
        ),
        content: Text(
          'You will be redirected. If the app is installed, it will open automatically.',
          style: TextStyle(color: Theme.of(context).colorScheme.darkGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Navigate to the standard web URL. The OS handles the redirection.
              html.window.open(universalLink, '_self');
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.blue,
            ),
            child: Text(
              'Open in App',
              style: TextStyle(color: Theme.of(context).colorScheme.light),
            ),
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
          const SizedBox(height: 16),
          Text(
            'Invoice Not Found',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.dark,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
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

    return Column(
      children: [
        if (kIsWeb) ...[
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Have the app?"),
                SizedBox(width: 8),
                TextButton(
                  onPressed: () => _showAppInstallDialog(context, token),
                  child: Text("Open in App"),
                )
              ],
            ),
          )
        ],
        Expanded(
          child: Container(
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
                transform: const GradientRotation(3.14 / 4),
                tileMode: TileMode.clamp,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    padding: const EdgeInsets.all(24),
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
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Invoice',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.dark,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
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
                                        invoice.status == 'PAID'
                                            ? 'PAID'
                                            : 'UNPAID',
                                        style: TextStyle(
                                          color: invoice.status == 'PAID'
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .green
                                              : dateIsPassed
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .red
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
                                const SizedBox(height: 20),
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
                                  const SizedBox(height: 12),
                                  Text(
                                    invoice.description!,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.dark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      height: 1.5,
                                    ),
                                  ),
                                  if (invoice.description!.isNotEmpty) ...[
                                    Builder(
                                      builder: (context) {
                                        final urls =
                                            _extractUrls(invoice.description!);
                                        if (urls.isEmpty)
                                          return SizedBox.shrink();

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 16),
                                            Divider(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .gray
                                                  .withOpacity(0.3),
                                              height: 1,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Payment Links',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .dark,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...urls.map((url) {
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 8.0),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: GestureDetector(
                                                        onTap: () async {
                                                          String urlToOpen =
                                                              url;
                                                          if (!url.startsWith(
                                                                  'http://') &&
                                                              !url.startsWith(
                                                                  'https://')) {
                                                            urlToOpen =
                                                                'https://$url';
                                                          }

                                                          final uri = Uri.parse(
                                                              urlToOpen);
                                                          if (await canLaunchUrl(
                                                              uri)) {
                                                            await launchUrl(uri,
                                                                mode: LaunchMode
                                                                    .externalApplication);
                                                          } else {
                                                            Get.snackbar(
                                                                'Error',
                                                                'Could not open link');
                                                          }
                                                        },
                                                        child: Container(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  12),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .blue
                                                                .withOpacity(
                                                                    0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .blue
                                                                  .withOpacity(
                                                                      0.3),
                                                              width: 1.5,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.link,
                                                                size: 16,
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .blue,
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Expanded(
                                                                child: Text(
                                                                  url,
                                                                  style:
                                                                      TextStyle(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .blue,
                                                                    fontSize:
                                                                        14,
                                                                    decoration:
                                                                        TextDecoration
                                                                            .underline,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    GestureDetector(
                                                      onTap: () async {
                                                        await Clipboard.setData(
                                                            ClipboardData(
                                                                text: url));
                                                        Get.snackbar(
                                                          'Copied',
                                                          'Link copied to clipboard',
                                                          backgroundColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .green
                                                                  .withOpacity(
                                                                      0.2),
                                                          colorText:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .green,
                                                          duration: Duration(
                                                              seconds: 1),
                                                        );
                                                      },
                                                      child: Container(
                                                        padding:
                                                            EdgeInsets.all(10),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .green
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          border: Border.all(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .green
                                                                .withOpacity(
                                                                    0.3),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Icon(
                                                          Icons.copy,
                                                          size: 16,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .green,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
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
                                const SizedBox(height: 20),
                                if (invoice.senderName != null)
                                  _buildDetailRow(
                                    context,
                                    'From',
                                    invoice.senderName!,
                                    copyable: true,
                                  ),
                                if (invoice.senderIban != null)
                                  _buildDetailRow(
                                    context,
                                    'IBAN',
                                    invoice.senderIban!,
                                    copyable: true,
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
                                    copyable: true,
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
                          const SizedBox(height: 32),
                          if (isLoggedIn) ...[
                            ElevatedButton(
                              onPressed: () async {
                                try {
                                  final claimedInvoice =
                                      await _digitalInvoiceController
                                          .claimPublicInvoice(
                                    token: token,
                                    claimerUserId:
                                        userController.user.value.id!,
                                    claimerPrivateUserId: userController
                                        .user.value.privateUserId!,
                                  );

                                  if (claimedInvoice != null) {
                                    Get.snackbar(
                                      'Success',
                                      'Invoice claimed successfully!',
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .green
                                          .withOpacity(0.2),
                                      colorText:
                                          Theme.of(context).colorScheme.green,
                                    );

                                    Future.delayed(const Duration(seconds: 1),
                                        () {
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
                                    colorText:
                                        Theme.of(context).colorScheme.red,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.blue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                elevation: 8,
                                shadowColor: Theme.of(context)
                                    .colorScheme
                                    .blue
                                    .withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Claim This Invoice',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: () {
                                Get.to(() => PublicInvoiceView(token: token));
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: Colors.white, width: 2),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'View Full Details',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ] else ...[
                            ElevatedButton(
                              onPressed: () {
                                Get.toNamed(
                                  '/sign-in',
                                  parameters: {'invoice_token': token},
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.blue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                elevation: 8,
                                shadowColor: Theme.of(context)
                                    .colorScheme
                                    .blue
                                    .withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Sign Up to Claim Invoice',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () {
                                Get.toNamed(
                                  '/sign-in',
                                  parameters: {'invoice_token': token},
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
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
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.only(bottom: 16),
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
          const SizedBox(width: 16),
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      Get.snackbar(
                        'Copied!',
                        '$label copied to clipboard',
                        backgroundColor:
                            Theme.of(context).colorScheme.blue.withOpacity(0.2),
                        colorText: Theme.of(context).colorScheme.blue,
                        duration: const Duration(seconds: 2),
                        snackPosition: SnackPosition.BOTTOM,
                        margin: const EdgeInsets.all(16),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
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
