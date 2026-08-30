import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_loyalty/models/merchant_checkout_qr_model.dart';
import 'package:slickbill/feature_loyalty/repos/merchant_insights_repo.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';
import 'package:flutter/services.dart';

class MerchantCheckoutQrScreen extends StatefulWidget {
  const MerchantCheckoutQrScreen({super.key});

  @override
  State<MerchantCheckoutQrScreen> createState() =>
      _MerchantCheckoutQrScreenState();
}

class _MerchantCheckoutQrScreenState extends State<MerchantCheckoutQrScreen> {
  final _repo = MerchantInsightsRepo();
  MerchantCheckoutQrModel? _qr;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qr = await _repo.getCheckoutQr();
      if (!mounted) return;
      setState(() {
        _qr = qr;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is String ? e : e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final navy = Theme.of(context).colorScheme.blue;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.light,
      appBar: CustomAppbar(
        title: 'hd_MerchantCheckoutQr'.tr,
        appbarIcon: null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: Text('btn_Retry'.tr),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'lbl_MerchantCheckoutQrHint'.tr,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.darkGray,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: navy.withOpacity(0.2)),
                        ),
                        child: QrImageView(
                          data: _qr!.checkoutUrl,
                          version: QrVersions.auto,
                          size: 220,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: navy,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      _qr!.checkoutUrl,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.dark,
                          ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: _qr!.checkoutUrl),
                          );
                          Get.snackbar('inf_Copied'.tr, _qr!.checkoutUrl);
                        },
                        icon: const Icon(Icons.copy),
                        label: Text('btn_CopyCheckoutLink'.tr),
                      ),
                    ),
                  ],
                ),
    );
  }
}
