import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';
import 'package:slickbill/feature_public/models/public_invoice_model.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/digital_invoice_controller.dart';

class PublicInvoiceView extends HookWidget {
  final String token;

  const PublicInvoiceView({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final invoiceController = Get.find<DigitalInvoiceController>();
    final invoice = useState<PublicInvoiceModel?>(null);
    final isLoading = useState<bool>(true);
    final FormatNumber formatNumber = FormatNumber();

    useEffect(() {
      Future<void> loadInvoice() async {
        try {
          final loadedInvoice =
              await invoiceController.getPublicInvoiceByToken(token);
          invoice.value = loadedInvoice;
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
    bool dateIsPassed = inv.deadline != null &&
        DateTime.now().isAfter(DateTime.parse(inv.deadline!));

    return Scaffold(
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
                    value: inv.senderIban ?? '-',
                  ),

                  const SizedBox(height: 30),

                  // Account Holder
                  _buildCopyableField(
                    context,
                    label: 'Account Holder',
                    value: inv.senderName ?? '-',
                  ),

                  const SizedBox(height: 30),

                  // Description
                  _buildCopyableField(
                    context,
                    label: 'Description',
                    value: inv.description ?? '-',
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
                      // Sign Up / Claim Button
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
                            // TODO: Navigate to sign up or claim invoice
                            Get.snackbar(
                              'Coming Soon',
                              'Sign up to claim this invoice and track payments',
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .blue
                                  .withOpacity(0.1),
                              colorText: Theme.of(context).colorScheme.blue,
                            );
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

                      // Mark as Paid Button
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
                            // TODO: Mark as paid functionality
                            Get.snackbar(
                              'Coming Soon',
                              'Mark this invoice as paid',
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .blue
                                  .withOpacity(0.1),
                              colorText: Theme.of(context).colorScheme.blue,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Mark as Paid',
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
                                FontAwesomeIcons.checkDouble,
                                color: Theme.of(context).colorScheme.light,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
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
}
