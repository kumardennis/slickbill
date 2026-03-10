import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/shared_widgets/cdp_webview.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:slickbill/shared_widgets/sb_post_message_impl.dart';
import 'package:url_launcher/url_launcher.dart';

class CdpWalletBalance extends HookWidget {
  const CdpWalletBalance({super.key});

  @override
  Widget build(BuildContext context) {
    final UserController userController = Get.find();
    final walletAddress =
        useState<String?>(userController.user.value.cdpWalletId);
    final balance = useState<String>('0.00');
    final isLoadingBalance = useState(false);
    final balanceHasLoaded = useState(false);
    final messageSub = useRef<StreamSubscription?>(null);

    Future<dynamic> openWebView(String page) async {
      // ignore: avoid_print
      print('openWebView called page=$page');

      try {
        const baseUrl = 'https://slickbills-wallet-client.vercel.app';
        String url = '';
        String title = '';
        CdpAutoCloseMode autoCloseMode = CdpAutoCloseMode.none;

        switch (page) {
          case 'auth':
            url = '$baseUrl/wallet/auth';
            title = 'Get your wallet!';
            autoCloseMode = CdpAutoCloseMode.auth;
            break;
          case 'balance':
            url = '$baseUrl/wallet/balance';
            title = 'My Balance';
            autoCloseMode = CdpAutoCloseMode.balance;
            break;
          case 'onramp':
            url = '$baseUrl/wallet/onramp';
            title = 'Add Funds';
            autoCloseMode = CdpAutoCloseMode.onrampUrl;
            break;
          case 'pay':
            url = '$baseUrl/wallet/pay';
            title = 'Send Payment';
            autoCloseMode = CdpAutoCloseMode.pay;
            break;
        }

        final token = userController.user.value.accessToken;
        // ignore: avoid_print
        print(
            'navigating to CdpWebView url=$url tokenPresent=${token != null && token.isNotEmpty}');

        final result = await Get.to(() => CdpWebView(
              url: url,
              title: title,
              accessToken: token,
              autoCloseMode: autoCloseMode,
            ));

        // ignore: avoid_print
        print('CdpWebView returned: $result');
        return result;
      } catch (e, st) {
        // ignore: avoid_print
        print('openWebView failed: $e');
        // ignore: avoid_print
        print(st);
      }
    }

    Future<void> getWalletForUser() async {
      final result = await openWebView('auth');

      if (result is Map && result['address'] is String) {
        walletAddress.value = result['address'] as String;
        balance.value = '0.00';
        balanceHasLoaded.value = true;

        final success = await userController.updateCdpWalletAddress(
          walletAddress.value!,
          result['cdpUserId'] is String ? result['cdpUserId'] as String : '',
        );

        if (success) {
          Get.snackbar(
            'Success',
            'Wallet linked successfully',
            backgroundColor: Theme.of(context).colorScheme.green,
            colorText: Colors.white,
          );
        }
      } else {
        Get.snackbar(
          'Error',
          'Failed to link wallet. Please try again.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
      }
    }

    Future<void> addFunds() async {
      final result = await openWebView('onramp');

      if (result is Map && result['onrampUrl'] is String) {
        final url = result['onrampUrl'] as String;
        if (kIsWeb) {
          // In web, the onramp page opens in the same tab, so we just show a message.
          Get.snackbar(
            'Onramp Opened',
            'Please complete the process in the opened page.',
            backgroundColor: Theme.of(context).colorScheme.green,
            colorText: Colors.white,
          );
        } else {
          // In mobile, we can open the onramp URL in an external browser.
          await launchUrl(Uri.parse(url));
        }
      } else {
        Get.snackbar(
          'Error',
          'Failed to open onramp. Please try again.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
      }
    }

    // ✅ New function to get balance silently
    Future<void> fetchBalance() async {
      if (walletAddress.value == null) return;

      isLoadingBalance.value = true;

      try {
        final result = await openWebView('balance');

        if (result is Map) {
          final bal = result['balance'];
          if (bal is String && bal.isNotEmpty) {
            balance.value = bal;
            balanceHasLoaded.value = true;
            debugPrint('✅ Balance updated: ${balance.value}');
          }

          final addr = result['address'];
          if (addr is String && addr.isNotEmpty) {
            walletAddress.value = addr;

            final success = await userController.updateCdpWalletAddress(
              addr,
              result['cdpUserId'] is String
                  ? result['cdpUserId'] as String
                  : '',
            );

            if (success) {
              Get.snackbar(
                'Success',
                'Wallet updated successfully',
                backgroundColor: Theme.of(context).colorScheme.green,
                colorText: Colors.white,
              );
            }
          }
        } else {
          debugPrint('fetchBalance: CdpWebView returned no result');
        }
      } catch (e) {
        debugPrint('❌ Error fetching balance: $e');
        Get.snackbar(
          'Error',
          'Failed to fetch balance',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
      } finally {
        isLoadingBalance.value = false;
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.blue,
            Theme.of(context).colorScheme.turqouise,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Your Wallet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        balanceHasLoaded.value
                            ? '€${double.parse(balance.value.toString()).toStringAsFixed(2)}'
                            : '- - -',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 36,
                                ),
                      ),
                      if (isLoadingBalance.value) ...[
                        const SizedBox(width: 12),
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'EURC Balance',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.coins,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Action Buttons
          if (walletAddress.value == null)
            // Sign In Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: getWalletForUser,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Get your wallet!',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Theme.of(context).colorScheme.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            // Wallet Actions
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isLoadingBalance.value ? null : fetchBalance,
                        icon:
                            const Icon(Icons.account_balance_wallet, size: 16),
                        label: const Text('Fetch Balance'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).colorScheme.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: addFunds,
                        icon: const Icon(Icons.add_card, size: 16),
                        label: const Text('Add Funds'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).colorScheme.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                // Wallet Address
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wallet Address',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (_) {
                                final full = walletAddress.value;
                                if (full == null || full.length < 10) {
                                  return Text(
                                    '-',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontFamily: 'monospace',
                                        ),
                                  );
                                }

                                return Text(
                                  '${full.substring(0, 6)}...${full.substring(full.length - 4)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontFamily: 'monospace',
                                      ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              final full = walletAddress.value;
                              if (full == null || full.isEmpty) return;

                              await Clipboard.setData(
                                  ClipboardData(text: full));
                              Get.snackbar(
                                'Copied',
                                'Wallet address copied',
                                backgroundColor:
                                    Theme.of(context).colorScheme.green,
                                colorText: Colors.white,
                                duration: const Duration(seconds: 1),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.copy,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
