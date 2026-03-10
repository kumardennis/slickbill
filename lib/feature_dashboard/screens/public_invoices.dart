import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';
import 'package:slickbill/feature_dashboard/widgets/sent_public_invoice_sheet.dart';
import 'package:slickbill/feature_public/models/public_invoice_model.dart';
import 'package:flutter/services.dart';
import 'package:slickbill/feature_dashboard/widgets/sent_invoice_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';
// ✅ Add this import

class PublicInvoices extends HookWidget {
  PublicInvoices({super.key});

  final UserController userController = Get.find();
  final DigitalInvoiceController invoiceController = Get.find();

  @override
  Widget build(BuildContext context) {
    var isLoading = useState<bool>(false);
    var publicInvoices = useState<List<PublicInvoiceModel>>([]);
    var expandedInvoices = useState<Set<int>>({});

    Future<void> loadPublicInvoices() async {
      isLoading.value = true;
      try {
        await invoiceController.loadPublicInvoices(
          userController.user.value.privateUserId!,
        );
        publicInvoices.value = invoiceController.publicInvoices;
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to load public invoices: $e',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      loadPublicInvoices();
      return null;
    }, []);

    void toggleExpanded(int invoiceId) {
      final newSet = Set<int>.from(expandedInvoices.value);
      if (newSet.contains(invoiceId)) {
        newSet.remove(invoiceId);
      } else {
        newSet.add(invoiceId);
      }
      expandedInvoices.value = newSet;
    }

    void copyLink(String token) {
      final url = 'https://app.slickbills.com/bill/$token';
      Clipboard.setData(ClipboardData(text: url));
      Get.snackbar(
        'Copied!',
        'Link copied to clipboard',
        backgroundColor: Theme.of(context).colorScheme.blue.withOpacity(0.1),
        colorText: Theme.of(context).colorScheme.blue,
        duration: Duration(seconds: 2),
      );
    }

    void showInvoiceDetails(BuildContext context, ClaimedInvoice claimed) {
      // Extract the actual InvoiceModel from ClaimedInvoice
      final invoice = claimed.digitalInvoices;

      if (invoice == null) {
        Get.snackbar(
          'Error',
          'Invoice details not available',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SentInvoiceSheet(
          invoice: invoice,
          updateInvoiceObsolete: () {
            // Reload public invoices after update
            loadPublicInvoices();
          },
        ),
      );
    }

    void showPublicInvoiceDetails(
        BuildContext context, PublicInvoiceModel invoice) {
      // Extract the actual InvoiceModel from ClaimedInvoice

      if (invoice == null) {
        Get.snackbar(
          'Error',
          'Invoice details not available',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => SentPublicInvoiceSheet(
          invoice: invoice,
          updateInvoiceObsolete: () {
            // Reload public invoices after update
            loadPublicInvoices();
          },
        ),
      );
    }

    // ✅ Updated QR code dialog function with brand colors
    void showQRCode(
        BuildContext context, String token, String description, double amount) {
      final publicLink = 'https://app.slickbills.com/bill/$token';

      Get.dialog(
        Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .blue
                                .withOpacity(0.15), // ✅ Blue
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.qr_code_2,
                            color: Theme.of(context).colorScheme.blue, // ✅ Blue
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Public Invoice QR',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.dark,
                                    ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Anyone can scan to view',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.darkGray,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: Icon(Icons.close),
                          color: Theme.of(context).colorScheme.darkGray,
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Invoice Info
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.light,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .gray
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            description,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.dark,
                                    ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '€${amount.toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .blue, // ✅ Blue for amount
                                ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // QR Code
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .lighterBlue
                              .withOpacity(0.3), // ✅ Lighter blue
                          width: 2,
                        ),
                      ),
                      child: QrImageView(
                        data: publicLink,
                        version: QrVersions.auto,
                        size: 220,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.circle,
                          color: Theme.of(context)
                              .colorScheme
                              .blue, // ✅ Blue QR eyes
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: Theme.of(context).colorScheme.dark,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Info text
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .lighterBlue
                            .withOpacity(0.1), // ✅ Lighter blue bg
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.blue, // ✅ Blue
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Opens in app if installed, or web browser',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.dark,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: publicLink));
                              Get.snackbar(
                                'Copied!',
                                'Link copied to clipboard',
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .lighterBlue
                                    .withOpacity(0.1), // ✅ Blue
                                colorText: Theme.of(context)
                                    .colorScheme
                                    .blue, // ✅ Blue
                                icon: Icon(Icons.check_circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .blue), // ✅ Blue
                                duration: Duration(seconds: 2),
                              );
                            },
                            icon: Icon(Icons.copy, size: 18),
                            label: Text('Copy Link'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.blue, // ✅ Blue
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .blue, // ✅ Blue
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Get.back(),
                            icon: Icon(Icons.close, size: 18),
                            label: Text('Close'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.blue, // ✅ Blue
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.light,
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.blue,
        onRefresh: loadPublicInvoices,
        child: isLoading.value
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.blue,
                ),
              )
            : publicInvoices.value.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.link_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.gray,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Shareable Links Yet',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.dark,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create a shareable link from Send Invoice',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.darkGray,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(0, 20, 20, 0),
                    itemCount: publicInvoices.value.length,
                    itemBuilder: (context, index) {
                      final publicInvoice = publicInvoices.value[index];
                      final isExpanded =
                          expandedInvoices.value.contains(publicInvoice.id);
                      final claimedCount =
                          publicInvoice.claimedInvoices?.length ?? 0;

                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.light,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(0),
                            topRight: Radius.circular(28),
                            bottomLeft: Radius.circular(0),
                            bottomRight: Radius.circular(28),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.blue,
                              Theme.of(context)
                                  .colorScheme
                                  .turqouise
                                  .withOpacity(0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .dark
                                  .withOpacity(0.1),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Main public invoice info - SEPARATE TAP AREA
                            Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tappable main content
                                  GestureDetector(
                                    onTap: () {
                                      // ✅ FIX: Only show details if there are claimed invoices
                                      if (publicInvoice.claimedInvoices !=
                                              null &&
                                          publicInvoice
                                              .claimedInvoices!.isNotEmpty) {
                                        showPublicInvoiceDetails(
                                            context, publicInvoice);
                                      } else {
                                        // Show the public invoice details instead
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (context) =>
                                              SentPublicInvoiceSheet(
                                            invoice: publicInvoice,
                                            updateInvoiceObsolete:
                                                loadPublicInvoices,
                                          ),
                                        );
                                      }
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    publicInvoice.description ??
                                                        'No description',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineSmall
                                                        ?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .light,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                  SizedBox(height: 6),
                                                  Text(
                                                    'Created ${DateFormat('MMM dd, yyyy').format(publicInvoice.createdAt)}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .lightGray,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '€${publicInvoice.amount.toStringAsFixed(2)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineMedium
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .light,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                                SizedBox(height: 6),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: claimedCount > 0
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .lighterBlue
                                                            .withOpacity(0.15)
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .gray
                                                            .withOpacity(0.3),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Text(
                                                    '$claimedCount claimed',
                                                    style: TextStyle(
                                                      color: claimedCount > 0
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .lightGray
                                                          : Theme.of(context)
                                                              .colorScheme
                                                              .darkGray,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Divider(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .gray
                                        .withOpacity(0.3),
                                    height: 1,
                                  ),
                                  SizedBox(height: 12),
                                  // Bottom row with separate tap areas
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.visibility_outlined,
                                            size: 18,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .lightGray,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            '${publicInvoice.viewCount} views',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .lightGray,
                                                ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          // ✅ QR Code button with brand blue color
                                          IconButton(
                                            icon: Icon(
                                              Icons.qr_code_2,
                                              size: 20,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .lightGray, // ✅ Changed from green to blue
                                            ),
                                            onPressed: () => showQRCode(
                                              context,
                                              publicInvoice.publicToken ?? "",
                                              publicInvoice.description ??
                                                  "Invoice",
                                              publicInvoice.amount,
                                            ),
                                            tooltip: 'Show QR Code',
                                            padding: EdgeInsets.all(8),
                                            constraints: BoxConstraints(),
                                          ),
                                          SizedBox(width: 8),
                                          IconButton(
                                            icon: Icon(
                                              Icons.copy_outlined,
                                              size: 20,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .lightGray,
                                            ),
                                            onPressed: () => copyLink(
                                                publicInvoice.publicToken ??
                                                    ""),
                                            tooltip: 'Copy link',
                                            padding: EdgeInsets.all(8),
                                            constraints: BoxConstraints(),
                                          ),
                                          SizedBox(width: 8),
                                          // Expand/collapse button - SEPARATE TAP AREA
                                          GestureDetector(
                                            onTap: () => toggleExpanded(
                                                publicInvoice.id),
                                            child: Container(
                                              padding: EdgeInsets.all(8),
                                              child: Icon(
                                                isExpanded
                                                    ? Icons.expand_less
                                                    : Icons.expand_more,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .lightGray,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Expanded claimed invoices list
                            if (isExpanded && claimedCount > 0)
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .gray
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Claimed by:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .lightGray,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    SizedBox(height: 12),
                                    ...publicInvoice.claimedInvoices!
                                        .map((claimed) {
                                      final receiverName = claimed
                                                  .digitalInvoices
                                                  ?.receivers
                                                  .privateUsers !=
                                              null
                                          ? '${claimed.digitalInvoices?.receivers.privateUsers?.firstName} ${claimed.digitalInvoices?.receivers.privateUsers?.lastName}'
                                          : claimed.digitalInvoices?.receivers
                                                  .businessUsers?.publicName ??
                                              'Unknown';

                                      return GestureDetector(
                                        onTap: () => showInvoiceDetails(
                                            context, claimed),
                                        behavior: HitTestBehavior
                                            .opaque, // ADD THIS to prevent parent tap
                                        child: Container(
                                          margin: EdgeInsets.only(bottom: 12),
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .light,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .gray
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .blue
                                                        .withOpacity(0.2),
                                                child: Text(
                                                  receiverName[0].toUpperCase(),
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .blue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      receiverName,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .dark,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'Claimed ${DateFormat('MMM dd, HH:mm').format(DateTime.parse(claimed.createdAt!))}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .darkGray,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: claimed.digitalInvoices
                                                              ?.status
                                                              .toLowerCase() ==
                                                          'paid'
                                                      ? Colors.green
                                                          .withOpacity(0.15)
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .blue
                                                          .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  claimed
                                                      .digitalInvoices!.status
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color: claimed
                                                                .digitalInvoices!
                                                                .status
                                                                .toLowerCase() ==
                                                            'paid'
                                                        ? Colors.green
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .blue,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.chevron_right,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .gray,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
