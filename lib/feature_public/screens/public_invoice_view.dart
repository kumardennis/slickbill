import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/core/services/view_tracking_service.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/feature_public/models/public_invoice_model.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicInvoiceView extends HookWidget {
  final String token;

  const PublicInvoiceView({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final invoiceController = Get.find<DigitalInvoiceController>();
    final userController = Get.find<UserController>();
    final invoice = useState<PublicInvoiceModel?>(null);
    final isLoading = useState<bool>(true);
    final FormatNumber formatNumber = FormatNumber();

    final _supabase = Supabase.instance.client;

    Future<void> cleanupOldViews(SharedPreferences prefs) async {
      final keys = prefs.getKeys();
      final now = DateTime.now();

      for (final key in keys) {
        if (key.startsWith('viewed_invoice_')) {
          final dateStr = prefs.getString(key);
          if (dateStr != null) {
            final viewDate = DateTime.parse(dateStr);
            if (now.difference(viewDate).inDays > 30) {
              await prefs.remove(key);
              print('🗑️ Cleaned up old view: $key');
            }
          }
        }
      }
    }

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
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.blue,
          ),
        ),
      );
    }

    if (invoice.value == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              // ✅ Go to landing page
              Get.offAllNamed('/');
            },
          ),
          title: Text('Slickbill'),
        ),
        body: Center(
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
        ),
      );
    }

    final inv = invoice.value!;
    final isSignedIn = userController.user.value.id != 0;
    final isClaimed = inv.receiverPrivateUserId != null;
    bool dateIsPassed = inv.deadline != null &&
        DateTime.now().isAfter(DateTime.parse(inv.deadline!));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.light,
          ),
          onPressed: () {
            // ✅ Always go back to the previous screen
            if (Get.currentRoute == '/public-invoice') {
              // If on public invoice route, go to landing
              Get.offAllNamed('/');
            } else {
              // Otherwise just go back
              Get.back();
            }
          },
        ),
        title: Text(
          'Slickbill',
          style: TextStyle(color: Theme.of(context).colorScheme.light),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
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
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shared Invoice',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.light,
                                ),
                          ),
                          Text(
                            DateFormat('EEE, dd MMM yyyy')
                                .format(inv.createdAt),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.gray,
                                    ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                inv.status == 'PAID' ? 'Paid' : 'Unpaid',
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium
                                    ?.copyWith(
                                      color: inv.status == 'PAID'
                                          ? Theme.of(context).colorScheme.green
                                          : dateIsPassed
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .red
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .yellow,
                                    ),
                              ),
                              const SizedBox(width: 10),
                              inv.status == 'PAID'
                                  ? FaIcon(
                                      FontAwesomeIcons.circleCheck,
                                      size: 20,
                                      color:
                                          Theme.of(context).colorScheme.green,
                                    )
                                  : FaIcon(
                                      FontAwesomeIcons.clockRotateLeft,
                                      size: 20,
                                      color: dateIsPassed
                                          ? Theme.of(context).colorScheme.red
                                          : Theme.of(context)
                                              .colorScheme
                                              .yellow,
                                    ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            formatNumber.formatMoney(inv.amount),
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.light,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Divider(
                      color: Theme.of(context).colorScheme.gray,
                      thickness: 3,
                      height: 20,
                    ),
                  ),

                  // Invoice Number & Deadline
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width / 2,
                            child: Text(
                              inv.originalInvoiceNo != null
                                  ? '#${inv.originalInvoiceNo}'
                                  : '-',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.light,
                                  ),
                            ),
                          ),
                          Text(
                            'Original Invoice No',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.gray,
                                    ),
                          ),
                        ],
                      ),
                      if (inv.deadline != null)
                        Text(
                          inv.paidOnDate != null
                              ? 'Paid on ${DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(inv.paidOnDate!))}'
                              : 'Due ${DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(inv.deadline!))}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: inv.paidOnDate != null
                                    ? Theme.of(context).colorScheme.green
                                    : dateIsPassed
                                        ? Theme.of(context).colorScheme.red
                                        : Theme.of(context).colorScheme.yellow,
                              ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 50),

                  // IBAN
                  _buildCopyableField(
                    context,
                    label: 'IBAN',
                    value: inv.sender?.iban ?? '-',
                  ),

                  const SizedBox(height: 30),

                  // Account Holder
                  _buildCopyableField(
                    context,
                    label: 'Account Holder',
                    value: inv.sender?.bankAccountName ?? '-',
                  ),

                  const SizedBox(height: 30),

                  // Description - Make it more prominent
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .light
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Description',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.gray,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                if (inv.description != null &&
                                    inv.description!.isNotEmpty) {
                                  await Clipboard.setData(
                                      ClipboardData(text: inv.description!));
                                  Get.snackbar(
                                    'Copied',
                                    'Description copied to clipboard',
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .green
                                        .withOpacity(0.1),
                                    colorText:
                                        Theme.of(context).colorScheme.green,
                                    duration: Duration(seconds: 2),
                                  );
                                }
                              },
                              child: FaIcon(
                                FontAwesomeIcons.copy,
                                color: Theme.of(context).colorScheme.light,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          inv.description ?? '-',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.light,
                                    height: 1.5,
                                  ),
                        ),
                        // Extract and show links
                        if (inv.description != null &&
                            inv.description!.isNotEmpty) ...[
                          Builder(
                            builder: (context) {
                              final urls = _extractUrls(inv.description!);
                              if (urls.isEmpty) return SizedBox.shrink();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 16),
                                  Divider(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .light
                                        .withOpacity(0.3),
                                    height: 1,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Payment Links',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .light,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...urls.map((url) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () async {
                                                String urlToOpen = url;
                                                if (!url.startsWith(
                                                        'http://') &&
                                                    !url.startsWith(
                                                        'https://')) {
                                                  urlToOpen = 'https://$url';
                                                }

                                                final uri =
                                                    Uri.parse(urlToOpen);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri,
                                                      mode: LaunchMode
                                                          .externalApplication);
                                                } else {
                                                  Get.snackbar('Error',
                                                      'Could not open link');
                                                }
                                              },
                                              child: Container(
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(
                                                      0.15), // ✅ Increased opacity
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .light
                                                        .withOpacity(
                                                            0.5), // ✅ Lighter border
                                                    width:
                                                        1.5, // ✅ Thicker border
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.link,
                                                      size: 16,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .light,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        url,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .light,
                                                              decoration:
                                                                  TextDecoration
                                                                      .underline,
                                                              decorationColor:
                                                                  Theme.of(
                                                                          context)
                                                                      .colorScheme
                                                                      .light,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
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
                                                  ClipboardData(text: url));
                                              Get.snackbar(
                                                'Copied',
                                                'Link copied to clipboard',
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .green
                                                        .withOpacity(0.2),
                                                colorText: Theme.of(context)
                                                    .colorScheme
                                                    .light, // ✅ White text
                                                duration: Duration(seconds: 1),
                                              );
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .light
                                                      .withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.copy,
                                                size: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .light,
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
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Category
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv.category ?? '-',
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.light,
                                ),
                          ),
                          Text(
                            'Category',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.gray,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Reference Number
                  _buildCopyableField(
                    context,
                    label: 'Reference Number',
                    value: inv.referenceNo ?? '-',
                  ),

                  const SizedBox(height: 50),

                  // Action Buttons
                  Column(
                    children: [
                      if (!isSignedIn) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.green,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Get.offAllNamed('/sign-in', arguments: {
                                'invoice_token': token,
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Sign Up to Claim Invoice',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.light,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(width: 10),
                                FaIcon(
                                  FontAwesomeIcons.userPlus,
                                  color: Theme.of(context).colorScheme.light,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (inv.status != 'PAID' && !isClaimed)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSignedIn
                                  ? Theme.of(context).colorScheme.blue
                                  : Colors.transparent,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.light,
                                width: 2,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              try {
                                final claimedInvoice =
                                    await invoiceController.claimPublicInvoice(
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
                                  colorText: Theme.of(context).colorScheme.red,
                                );
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Claim This Invoice',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                FaIcon(
                                  FontAwesomeIcons.checkDouble,
                                  color: Theme.of(context).colorScheme.light,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (isSignedIn) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.light,
                                width: 2,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Get.offAllNamed('/home-screen');
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Go to Home',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color:
                                            Theme.of(context).colorScheme.light,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(width: 10),
                                FaIcon(
                                  FontAwesomeIcons.house,
                                  color: Theme.of(context).colorScheme.light,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCopyableField(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.light,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.gray,
                    ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () async {
            if (value != '-') {
              await Clipboard.setData(ClipboardData(text: value));
              Get.snackbar('Copied', value);
            }
          },
          child: FaIcon(
            FontAwesomeIcons.copy,
            color: Theme.of(context).colorScheme.gray,
          ),
        ),
      ],
    );
  }

  // Add helper function to extract URLs from text
  List<String> _extractUrls(String text) {
    final urlPattern = RegExp(
      r'(https?:\/\/[^\s]+)|(www\.[^\s]+)|([a-zA-Z0-9-]+\.(com|net|org|io|me|app|co)[^\s]*)',
      caseSensitive: false,
    );
    final matches = urlPattern.allMatches(text);
    return matches.map((match) => match.group(0)!).toList();
  }
}
