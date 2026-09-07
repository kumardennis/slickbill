import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_dashboard/widgets/from_business_badge.dart';
import 'package:slickbill/feature_public/models/public_invoice_model.dart';
import 'package:slickbill/feature_public/widgets/public_invoice_page.dart';
import 'package:slickbill/theme/sb_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicInvoiceView extends HookWidget {
  final String token;

  const PublicInvoiceView({super.key, required this.token});

  List<String> _extractUrls(String text) {
    final urlPattern = RegExp(
      r'(https?:\/\/[^\s]+)|(www\.[^\s]+)|([a-zA-Z0-9-]+\.(com|net|org|io|me|app|co)[^\s]*)',
      caseSensitive: false,
    );
    return urlPattern.allMatches(text).map((match) => match.group(0)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    final invoiceController = Get.find<DigitalInvoiceController>();
    final userController = Get.find<UserController>();
    final invoice = useState<PublicInvoiceModel?>(null);
    final isLoading = useState<bool>(true);

    useEffect(() {
      Future<void> loadInvoice() async {
        try {
          final loadedInvoice =
              await invoiceController.getPublicInvoiceByToken(token);
          invoice.value = loadedInvoice;
          invoiceController.trackPublicInvoiceView(token);
        } catch (e) {
          Get.snackbar('Error', 'Failed to load invoice: $e');
        } finally {
          isLoading.value = false;
        }
      }

      loadInvoice();
      return null;
    }, []);

    if (isLoading.value) {
      return const PublicInvoicePage(
        showAppBar: true,
        child: Center(
          child: CircularProgressIndicator(color: SbColors.deepNavy),
        ),
      );
    }

    if (invoice.value == null) {
      return PublicInvoicePage(
        showAppBar: true,
        onBack: () => Get.offAllNamed('/'),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
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
              ],
            ),
          ),
        ),
      );
    }

    final inv = invoice.value!;
    final isSignedIn = userController.user.value.id != 0;
    final isClaimed = inv.receiverPrivateUserId != null;
    final dateIsPassed = inv.deadline != null &&
        DateTime.now().isAfter(DateTime.parse(inv.deadline!));
    final urls = inv.description == null || inv.description!.isEmpty
        ? const <String>[]
        : _extractUrls(inv.description!);
    final statusColor = inv.status == 'PAID'
        ? SbColors.successGreen
        : dateIsPassed
            ? SbColors.error
            : SbColors.warningAmber;
    final statusLabel = inv.status == 'PAID'
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

    Future<void> claim() async {
      try {
        final claimerPrivateUserId = userController.user.value.privateUserId;
        if (claimerPrivateUserId == null) {
          Get.snackbar(
            'Sign in needed',
            'Please sign in again before claiming this invoice.',
          );
          return;
        }

        final existingInvoice =
            await invoiceController.getExistingClaimedInvoice(
          publicInvoiceId: inv.id,
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

    return PublicInvoicePage(
      showAppBar: true,
      onBack: () {
        if (Get.currentRoute == '/public-invoice') {
          Get.offAllNamed('/');
        } else {
          Get.back();
        }
      },
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PublicInvoiceHeroCard(
                    amount: inv.amount,
                    description: inv.description,
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
                                        duration: const Duration(seconds: 1),
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
                      PublicInvoiceDetailRow(
                        label: 'Created',
                        value: DateFormat('EEE, dd MMM yyyy')
                            .format(inv.createdAt),
                      ),
                      if (inv.originalInvoiceNo != null)
                        PublicInvoiceDetailRow(
                          label: 'Invoice no',
                          value: '#${inv.originalInvoiceNo}',
                        ),
                      if (inv.displaySenderName.isNotEmpty)
                        PublicInvoiceDetailRow(
                          label: 'From',
                          value: inv.displaySenderName,
                          copyable: true,
                        ),
                      if (inv.isFromBusiness)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FromBusinessBadge(),
                          ),
                        ),
                      PublicInvoiceDetailRow(
                        label: 'IBAN',
                        value: inv.sender?.iban ?? '-',
                        copyable: inv.sender?.iban != null,
                      ),
                      PublicInvoiceDetailRow(
                        label: 'Account',
                        value: inv.sender?.bankAccountName ?? '-',
                        copyable: inv.sender?.bankAccountName != null,
                      ),
                      PublicInvoiceDetailRow(
                        label: 'Category',
                        value: inv.category ?? '-',
                      ),
                      PublicInvoiceDetailRow(
                        label: 'Reference',
                        value: inv.referenceNo ?? '-',
                        copyable: inv.referenceNo != null &&
                            inv.referenceNo!.isNotEmpty,
                      ),
                      if (inv.deadline != null)
                        PublicInvoiceDetailRow(
                          label: inv.paidOnDate != null ? 'Paid' : 'Due',
                          value: DateFormat('EEE, dd MMM yyyy').format(
                            DateTime.parse(inv.paidOnDate ?? inv.deadline!),
                          ),
                          highlight: inv.paidOnDate == null && dateIsPassed,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  PublicInvoiceActions(
                    children: [
                      if (!isSignedIn) ...[
                        ElevatedButton(
                          onPressed: () {
                            Get.offAllNamed('/sign-in', arguments: {
                              'invoice_token': token,
                            });
                          },
                          child: const Text('Sign in to claim'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (inv.status != 'PAID' && !isClaimed && isSignedIn) ...[
                        ElevatedButton(
                          onPressed: claim,
                          child: const Text('Claim this invoice'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      OutlinedButton(
                        onPressed: () => Get.offAllNamed('/home-screen'),
                        child: const Text('Go to Home'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
