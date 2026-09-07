import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/utils/supabase_auth_manger.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_public/models/public_invoice_model.dart';
import 'package:slickbill/feature_dashboard/widgets/from_business_badge.dart';
import 'package:slickbill/feature_public/screens/public_invoice_view.dart';
import 'package:slickbill/feature_public/widgets/public_invoice_page.dart';
import 'package:slickbill/theme/sb_colors.dart';
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

            if (userController.user.value.privateUserId != null) {
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
                  backgroundColor: SbColors.error,
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
                backgroundColor: SbColors.error,
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
          final normalizedToken = token.trim();
          if (normalizedToken.isEmpty) {
            if (context.mounted) {
              Get.snackbar(
                'Invalid Link',
                'Missing public invoice token in this link.',
              );
            }
            return;
          }

          final loadedInvoice =
              await invoiceController.getPublicInvoiceByToken(normalizedToken);

          // ✅ Check if widget is still mounted before updating state
          if (!context.mounted) return;

          invoice.value = loadedInvoice;

          await invoiceController.trackPublicInvoiceView(normalizedToken);

          if (kIsWeb && !hasCheckedDeepLink.value) {
            hasCheckedDeepLink.value = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                _showAppInstallDialog(context, normalizedToken);
              }
            });
          }

          await _checkAuth();
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
    return PublicInvoicePage(
      child: isLoading.value
          ? const Center(
              child: CircularProgressIndicator(color: SbColors.deepNavy),
            )
          : invoice.value == null
              ? _buildErrorView(context)
              : _buildWebView(context, invoice.value!, userController),
    );
  }

  void _showAppInstallDialog(BuildContext context, String token) {
    final universalLink = 'slickbills://bill/$token';

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: SbColors.surfaceLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SbRadii.md),
          ),
          title: Text(
            'Open in SlickBills?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: SbColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
          content: Text(
            'If the app is installed, this invoice opens there. Otherwise stay here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: SbColors.onSurfaceVariant,
                ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(),
              child: Text(
                'Stay here',
                style: TextStyle(color: SbColors.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext, rootNavigator: true).pop();
                html.window.open(universalLink, '_self');
              },
              child: const Text('Open in app'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off_rounded,
              size: 48,
              color: SbColors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Invoice not found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: SbColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This link may be invalid or expired.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SbColors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Get.offAllNamed('/home-screen'),
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView(BuildContext context, PublicInvoiceModel invoice,
      UserController userController) {
    final isLoggedIn = userController.user.value.privateUserId != null;
    final dateIsPassed = invoice.deadline != null &&
        DateTime.now().isAfter(DateTime.parse(invoice.deadline!));
    final invoiceController = Get.find<DigitalInvoiceController>();
    final urls = invoice.description == null
        ? const <String>[]
        : _extractUrls(invoice.description!);
    final statusColor = invoice.status == 'PAID'
        ? SbColors.successGreen
        : dateIsPassed
            ? SbColors.error
            : SbColors.warningAmber;
    final statusLabel = invoice.status == 'PAID'
        ? 'Paid'
        : dateIsPassed
            ? 'Overdue'
            : 'Unpaid';

    Future<void> openUrl(String url) async {
      var urlToOpen = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        urlToOpen = 'https://$url';
      }
      final uri = Uri.parse(urlToOpen);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    return Column(
      children: [
        if (kIsWeb)
          PublicInvoiceAppPromptBar(
            onOpenApp: () => _showAppInstallDialog(context, token),
            onGoHome: () => Get.offAllNamed('/home-screen'),
          ),
        Expanded(
          child: SafeArea(
            top: !kIsWeb,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PublicInvoiceHeroCard(
                        amount: invoice.amount,
                        description: invoice.description,
                        statusLabel: statusLabel,
                        statusColor: statusColor,
                        extra: urls.isEmpty
                            ? null
                            : Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Links',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: SbColors.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...urls.map(
                                      (url) => PublicInvoiceLinkRow(
                                        url: url,
                                        onOpen: () => openUrl(url),
                                        onCopy: () async {
                                          await Clipboard.setData(
                                              ClipboardData(text: url));
                                          Get.snackbar(
                                            'Copied',
                                            'Link copied',
                                            snackPosition: SnackPosition.BOTTOM,
                                            margin: const EdgeInsets.all(16),
                                            duration:
                                                const Duration(seconds: 1),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      PublicInvoiceDetailsCard(
                        children: [
                          if (invoice.displaySenderName.isNotEmpty)
                            PublicInvoiceDetailRow(
                              label: 'From',
                              value: invoice.displaySenderName,
                              copyable: true,
                            ),
                          if (invoice.isFromBusiness)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: FromBusinessBadge(),
                              ),
                            ),
                          if (invoice.senderIban != null)
                            PublicInvoiceDetailRow(
                              label: 'IBAN',
                              value: invoice.senderIban!,
                              copyable: true,
                            ),
                          if (invoice.category != null)
                            PublicInvoiceDetailRow(
                              label: 'Category',
                              value: invoice.category!,
                            ),
                          if (invoice.referenceNo != null &&
                              invoice.referenceNo!.isNotEmpty)
                            PublicInvoiceDetailRow(
                              label: 'Reference',
                              value: invoice.referenceNo!,
                              copyable: true,
                            ),
                          if (invoice.deadline != null)
                            PublicInvoiceDetailRow(
                              label: 'Due',
                              value: DateFormat('EEE, dd MMM yyyy').format(
                                DateTime.parse(invoice.deadline!),
                              ),
                              highlight: dateIsPassed,
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PublicInvoiceActions(
                        children: [
                          if (isLoggedIn) ...[
                            ElevatedButton(
                              onPressed: () => _claimInvoice(
                                context: context,
                                invoice: invoice,
                                userController: userController,
                                invoiceController: invoiceController,
                              ),
                              child: const Text('Claim this invoice'),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () {
                                Get.to(() => PublicInvoiceView(token: token));
                              },
                              child: const Text('View full details'),
                            ),
                          ] else ...[
                            ElevatedButton(
                              onPressed: () {
                                Get.toNamed(
                                  '/sign-in',
                                  parameters: {'invoice_token': token},
                                );
                              },
                              child: const Text('Sign in to claim'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Get.toNamed(
                                  '/sign-up',
                                  parameters: {'invoice_token': token},
                                );
                              },
                              child: Text(
                                'lbl_GoToSignUp'.tr,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _claimInvoice({
    required BuildContext context,
    required PublicInvoiceModel invoice,
    required UserController userController,
    required DigitalInvoiceController invoiceController,
  }) async {
    try {
      final claimerPrivateUserId = userController.user.value.privateUserId;
      if (claimerPrivateUserId == null) {
        Get.snackbar(
          'Sign in needed',
          'Please sign in again before claiming this invoice.',
        );
        return;
      }

      final existingInvoice = await invoiceController.getExistingClaimedInvoice(
        publicInvoiceId: invoice.id,
        claimerPrivateUserId: claimerPrivateUserId,
      );
      if (existingInvoice != null) {
        final openExisting = await showPublicInvoiceConfirm(
          context: context,
          title: 'Already claimed',
          body: 'You already claimed this invoice. Open your bills?',
          confirmLabel: 'Open',
        );
        if (openExisting) Get.offAllNamed('/home-screen');
        return;
      }

      final confirmClaim = await showPublicInvoiceConfirm(
        context: context,
        title: 'Claim this invoice?',
        body: 'It will be added to your SlickBills account.',
        confirmLabel: 'Claim',
      );
      if (!confirmClaim) return;

      final claimedInvoice = await invoiceController.claimPublicInvoice(
        token: token,
        claimerPrivateUserId: claimerPrivateUserId,
      );
      if (claimedInvoice != null) {
        Get.snackbar('Claimed', 'This invoice is now in your bills.');
        Future.delayed(const Duration(seconds: 1), () {
          Get.offAllNamed('/home-screen');
        });
      }
    } catch (e) {
      Get.snackbar('Could not claim', e.toString());
    }
  }
}
