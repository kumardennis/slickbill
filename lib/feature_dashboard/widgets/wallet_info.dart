import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/models/user_model.dart';
import 'package:slickbill/feature_auth/services/metamask_wallet_service.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/payment_setup_controller.dart';
import 'package:slickbill/feature_dashboard/utils/received_invoices_class.dart';
import 'package:slickbill/feature_dashboard/utils/sent_invoices_class.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class WalletInfo extends HookWidget {
  const WalletInfo({super.key});

  @override
  Widget build(BuildContext context) {
    SentInvoicesClass sentInvoicesClass = SentInvoicesClass();
    ReceivedInvoicesClass receivedInvoicesClass = ReceivedInvoicesClass();
    UserController userController = Get.find();

    var pendingReceived = useState<double?>(0.0);
    var pendingSending = useState<double?>(0.0);

    var isConnectingMetamask = useState(false);
    var isConnectingMonerium = useState(false);
    var isMoneriumConnected = useState(false);
    var isAddressLinked = useState(false);
    var moneriumIbans = useState<List<dynamic>>([]);
    var metamaskWalletAddress =
        useState<String?>(userController.user.value.metamaskWalletAddress);

    final PaymentSetupController paymentSetupController =
        Get.put(PaymentSetupController());
    final isMounted = useIsMounted();
    final setupComplete = useState(
      paymentSetupController.step.value == PaymentSetupStep.complete,
    );

    useEffect(() {
      final worker = ever(paymentSetupController.step, (PaymentSetupStep step) {
        setupComplete.value = step == PaymentSetupStep.complete;
      });
      return worker.dispose;
    }, []);

    Future<bool> isAddressLinkedOnMonerium({
      required String userId,
      required String walletAddress,
    }) async {
      final linkedAddressesResponse = await MoneriumService.getLinkedAddresses(
        userId: userId,
        address: walletAddress,
      );

      final linked = linkedAddressesResponse['linked'];
      if (linked is bool) {
        return linked;
      }

      debugPrint(
        '[WalletConnectUI] isAddressLinkedOnMonerium(): backend linked missing for userId=$userId, treating as not linked',
      );
      return false;
    }

    Future<bool> linkAddressWithVerification({
      required String userId,
      required String walletAddress,
    }) async {
      final signature = await MetamaskWalletService.signAddressOwnershipMessage(
        address: walletAddress,
      );

      final linkResponse = await MoneriumService.linkWallet(
        userId: userId,
        address: walletAddress,
        message: MetamaskWalletService.moneriumOwnershipMessage,
        signature: signature,
      );

      final linkedConfirmed = linkResponse['linkedConfirmed'];
      final linkedAfterRequest = linkedConfirmed is bool
          ? linkedConfirmed
          : await isAddressLinkedOnMonerium(
              userId: userId,
              walletAddress: walletAddress,
            );

      return linkedAfterRequest;
    }

    String userFriendlyMoneriumError(Object error) {
      final message = error.toString();
      if (message.contains("429") || message.contains("Non-200 status code")) {
        return 'Rate limited by wallet provider. Wait 30-60 seconds and try again.';
      }
      return message;
    }

    String normalizeWalletAddress(String? address) {
      if (address == null) return '';
      return address.trim().toLowerCase();
    }

    String resolveMoneriumUserId() {
      final privateUserId = userController.user.value.privateUserId;
      if (privateUserId != null && privateUserId > 0) {
        return privateUserId.toString();
      }
      return userController.user.value.id.toString();
    }

    String? getMoneriumAddressFromRow(dynamic row) {
      if (row is! Map<String, dynamic>) {
        return null;
      }

      final candidates = [
        row['address'],
        row['walletAddress'],
        row['wallet_address'],
      ];

      for (final candidate in candidates) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }

      final wallet = row['wallet'];
      if (wallet is Map<String, dynamic>) {
        final nested = wallet['address'];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim();
        }
      }

      return null;
    }

    List<dynamic> filterIbansForWallet({
      required List<dynamic> ibans,
      required String? walletAddress,
    }) {
      final normalizedWallet = normalizeWalletAddress(walletAddress);
      if (normalizedWallet.isEmpty) {
        return ibans;
      }

      return ibans.where((row) {
        final rowAddress = getMoneriumAddressFromRow(row);
        if (rowAddress == null || rowAddress.isEmpty) {
          return true;
        }
        return normalizeWalletAddress(rowAddress) == normalizedWallet;
      }).toList(growable: false);
    }

    Future<List<dynamic>> refreshMoneriumIbansNow({
      required String userId,
      String? walletAddress,
    }) async {
      final ibansResponse = await MoneriumService.getIbans(userId: userId);
      final ibans = MoneriumService.extractIbans(ibansResponse['data']);
      final filteredIbans = filterIbansForWallet(
        ibans: ibans,
        walletAddress: walletAddress,
      );

      final moneriumBankAccounts = <BankAccount>[];
      for (final row in filteredIbans) {
        String? moneriumIban;
        if (row is Map<String, dynamic>) {
          final value = row['iban'];
          if (value is String && value.trim().isNotEmpty) {
            moneriumIban = value.trim();
          }
        }
        if (moneriumIban == null || moneriumIban.isEmpty) {
          continue;
        }

        String? accountHolderName;
        if (row is Map<String, dynamic>) {
          final directCandidates = [
            row['accountHolderName'],
            row['account_holder_name'],
            row['accountHolder'],
            row['account_holder'],
            row['bankAccountName'],
            row['bank_account_name'],
            row['name'],
          ];

          for (final candidate in directCandidates) {
            if (candidate is String && candidate.trim().isNotEmpty) {
              accountHolderName = candidate.trim();
              break;
            }
          }

          final account = row['account'];
          if (accountHolderName == null && account is Map<String, dynamic>) {
            final nestedCandidates = [
              account['holderName'],
              account['holder_name'],
              account['accountHolderName'],
              account['account_holder_name'],
              account['name'],
            ];
            for (final candidate in nestedCandidates) {
              if (candidate is String && candidate.trim().isNotEmpty) {
                accountHolderName = candidate.trim();
                break;
              }
            }
          }
        }

        moneriumBankAccounts.add(
          BankAccount(
            iban: moneriumIban,
            bankName: 'Monerium (LHV)',
            bankAccountName: accountHolderName,
            isPrimary: false,
          ),
        );
      }

      if (moneriumBankAccounts.isNotEmpty) {
        await userController.upsertIbansJson(moneriumBankAccounts);
        await paymentSetupController.markIbanReady();
      }

      if (isMounted()) {
        moneriumIbans.value = filteredIbans;
        if (filteredIbans.isNotEmpty) {
          isMoneriumConnected.value = true;
          isAddressLinked.value = true;
        }
      }

      return filteredIbans;
    }

    Future<void> resetMoneriumStateIfWalletChanged({
      required String? previousAddress,
      required String? nextAddress,
    }) async {
      final prev = previousAddress?.trim().toLowerCase() ?? '';
      final next = nextAddress?.trim().toLowerCase() ?? '';

      if (prev.isEmpty || next.isEmpty || prev == next) {
        return;
      }

      final userId = resolveMoneriumUserId();
      if (userId.isEmpty || userId == '0') {
        return;
      }

      await MoneriumService.clearStoredSession(userId: userId);

      if (!isMounted()) return;
      moneriumIbans.value = const [];
      isMoneriumConnected.value = false;
      isAddressLinked.value = false;
      debugPrint(
        '[WalletConnectUI] wallet changed; cleared Monerium session and cached IBANs',
      );
      await paymentSetupController.refresh();
    }

    String? getMoneriumAccountHolderFromRow(dynamic row) {
      if (row is! Map<String, dynamic>) {
        return null;
      }

      final directCandidates = [
        row['accountHolderName'],
        row['account_holder_name'],
        row['accountHolder'],
        row['account_holder'],
        row['bankAccountName'],
        row['bank_account_name'],
        row['name'],
      ];

      for (final candidate in directCandidates) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }

      final account = row['account'];
      if (account is Map<String, dynamic>) {
        final nestedCandidates = [
          account['holderName'],
          account['holder_name'],
          account['accountHolderName'],
          account['account_holder_name'],
          account['name'],
        ];
        for (final candidate in nestedCandidates) {
          if (candidate is String && candidate.trim().isNotEmpty) {
            return candidate.trim();
          }
        }
      }

      return null;
    }

    Future<String?> pickWeb3AuthProvider() async {
      return showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Choose Web3Auth provider',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.g_mobiledata),
                  title: const Text('Google'),
                  onTap: () => Navigator.of(sheetContext).pop('google'),
                ),
                ListTile(
                  leading: const Icon(Icons.facebook),
                  title: const Text('Facebook'),
                  onTap: () => Navigator.of(sheetContext).pop('facebook'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    }

    Future<void> handleConnectMetamask({
      String loginProvider = 'google',
    }) async {
      if (!isMounted()) return;
      debugPrint('[WalletConnectUI] connect tap received');
      isConnectingMetamask.value = true;

      try {
        final previousAddress = userController.user.value.metamaskWalletAddress;
        debugPrint('[WalletConnectUI] calling connectWalletAddress()');
        final address = await MetamaskWalletService.connectWalletAddress(
          accessToken: userController.user.value.accessToken,
          loginProvider: loginProvider,
        );
        debugPrint(
            '[WalletConnectUI] connectWalletAddress() returned empty=${address == null || address.isEmpty}');

        if (address == null || address.isEmpty) {
          throw Exception('No wallet address returned from Web3Auth login.');
        }

        debugPrint(
            '[WalletConnectUI] saving wallet address for user=${userController.user.value.id}');
        final updated =
            await userController.updateMetamaskWalletAddress(address);
        debugPrint('[WalletConnectUI] save result=$updated');

        if (!updated) {
          throw Exception(
              'Failed to save Web3Auth wallet address for user ID ${userController.user.value.id}.');
        }

        if (!isMounted()) return;
        metamaskWalletAddress.value = address;
        await resetMoneriumStateIfWalletChanged(
          previousAddress: previousAddress,
          nextAddress: address,
        );
        await paymentSetupController.refresh();

        Get.snackbar(
          'Success',
          'Web3Auth wallet connected and saved.',
          backgroundColor: Theme.of(context).colorScheme.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } catch (e) {
        debugPrint('[WalletConnectUI] connect failed: $e');
        if (!isMounted()) return;
        Get.snackbar(
          'Error',
          'Failed to connect Web3Auth wallet: ${e.toString()}',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } finally {
        debugPrint(
            '[WalletConnectUI] connect flow finished, resetting loading');
        if (isMounted()) {
          isConnectingMetamask.value = false;
        }
      }
    }

    Future<void> handleMoneriumConnect({
      bool forceBrowserReconnect = false,
    }) async {
      if (!isMounted()) return;

      final user = userController.user.value;
      final walletAddress = metamaskWalletAddress.value?.trim();
      final email = user.email.trim();

      if (walletAddress == null || walletAddress.isEmpty) {
        Get.snackbar(
          'Wallet Required',
          'Connect your wallet first before Monerium onboarding.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      if (email.isEmpty) {
        Get.snackbar(
          'Email Missing',
          'User email is required to continue Monerium onboarding.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      isConnectingMonerium.value = true;

      try {
        final userId = resolveMoneriumUserId();
        final wasAlreadyConnected = isMoneriumConnected.value;
        final shouldStartOAuth = forceBrowserReconnect || !wasAlreadyConnected;

        if (shouldStartOAuth) {
          if (forceBrowserReconnect) {
            await MoneriumService.clearStoredSession(userId: userId);
          }
          // OAuth-only connect: do not pass walletAddress (avoids SIWE signing).
          // Address ownership signing belongs in the Link Address step.
          await MoneriumService.connect(
            userId: userId,
            email: email,
            forceLogin: forceBrowserReconnect,
          );
        }

        final hasSession =
            await MoneriumService.hasActiveSession(userId: userId);
        if (!hasSession) {
          throw Exception('Monerium session was not established.');
        }

        // Refresh IBANs if they already exist, but never auto-link here.
        final ibans = await refreshMoneriumIbansNow(
          userId: userId,
          walletAddress: walletAddress,
        );

        if (!isMounted()) return;

        moneriumIbans.value = ibans;
        isMoneriumConnected.value = true;

        if (ibans.isNotEmpty) {
          isAddressLinked.value = true;
          await MoneriumService.setAddressLinked(
            userId: userId,
            linked: true,
          );
          await paymentSetupController.markIbanReady();
          Get.snackbar(
            'Monerium Ready',
            'Slickbills/Monerium iban found',
            backgroundColor: Theme.of(context).colorScheme.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        } else {
          await paymentSetupController.markMoneriumConnected();
          Get.snackbar(
            'Monerium Connected',
            'Next: link your wallet address, then request an IBAN.',
            backgroundColor: Theme.of(context).colorScheme.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      } catch (e) {
        if (!isMounted()) return;
        Get.snackbar(
          'Monerium Error',
          userFriendlyMoneriumError(e),
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } finally {
        if (isMounted()) {
          isConnectingMonerium.value = false;
        }
      }
    }

    // ignore: unused_element
    Future<void> handleGetIbanForTesting() async {
      if (!isMounted()) return;

      final user = userController.user.value;
      final walletAddress = metamaskWalletAddress.value?.trim();
      final email = user.email.trim();

      if (walletAddress == null || walletAddress.isEmpty) {
        Get.snackbar(
          'Wallet Required',
          'Connect your wallet first before testing IBAN lookup.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      if (email.isEmpty) {
        Get.snackbar(
          'Email Missing',
          'User email is required to continue Monerium testing.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      isConnectingMonerium.value = true;

      try {
        final userId = resolveMoneriumUserId();
        var linkedDuringThisAttempt = false;

        if (!isMoneriumConnected.value) {
          await MoneriumService.connect(
            userId: userId,
            email: email,
            walletAddress: walletAddress,
          );
        }

        var ibans = await refreshMoneriumIbansNow(
          userId: userId,
          walletAddress: walletAddress,
        );

        if (ibans.isEmpty) {
          final alreadyLinked = await isAddressLinkedOnMonerium(
            userId: userId,
            walletAddress: walletAddress,
          );

          if (alreadyLinked) {
            linkedDuringThisAttempt = true;
          } else {
            final linkedConfirmedAfterRequest =
                await linkAddressWithVerification(
              userId: userId,
              walletAddress: walletAddress,
            );
            linkedDuringThisAttempt = linkedConfirmedAfterRequest;
          }

          ibans = await refreshMoneriumIbansNow(
            userId: userId,
            walletAddress: walletAddress,
          );
        }

        final hasIbans = ibans.isNotEmpty;

        if (isMounted()) {
          moneriumIbans.value = ibans;
          isMoneriumConnected.value = hasIbans;
        }

        if (!isMounted()) return;

        Get.snackbar(
          'IBAN Lookup',
          hasIbans
              ? 'Slickbills/Monerium iban found'
              : (linkedDuringThisAttempt
                  ? 'Wallet link is confirmed, but Monerium has not created an IBAN yet. Please complete pending Monerium verification/provisioning steps.'
                  : 'Link request was accepted, but confirmation is still pending. Please retry shortly.'),
          backgroundColor: hasIbans
              ? Theme.of(context).colorScheme.green
              : Colors.orange.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } catch (e) {
        if (!isMounted()) return;
        Get.snackbar(
          'Monerium Error',
          e.toString(),
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } finally {
        if (isMounted()) {
          isConnectingMonerium.value = false;
        }
      }
    }

    Future<void> handleLinkAddressOnly() async {
      if (!isMounted()) return;

      final user = userController.user.value;
      final walletAddress = metamaskWalletAddress.value?.trim();
      final email = user.email.trim();

      if (walletAddress == null || walletAddress.isEmpty) {
        Get.snackbar(
          'Wallet Required',
          'Connect your wallet first before linking address.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      if (email.isEmpty) {
        Get.snackbar(
          'Email Missing',
          'User email is required to continue address linking.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      isConnectingMonerium.value = true;

      try {
        final userId = resolveMoneriumUserId();
        final session = await MoneriumService.getStoredSession(userId: userId);
        final hasSessionToken =
            (session?['accessToken']?.toString().trim().isNotEmpty ?? false);

        if (!hasSessionToken) {
          if (!isMounted()) return;
          Get.snackbar(
            'Monerium Required',
            'Connect Monerium first, then link your wallet address.',
            backgroundColor: Colors.orange.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          return;
        }

        final linkedAfterRequest = await linkAddressWithVerification(
          userId: userId,
          walletAddress: walletAddress,
        );

        if (!isMounted()) return;
        isMoneriumConnected.value = true;
        if (linkedAfterRequest) {
          isAddressLinked.value = true;
          await paymentSetupController.markAddressLinked(userId: userId);
        } else {
          await paymentSetupController.refresh();
        }
        Get.snackbar(
          linkedAfterRequest ? 'Address Linked' : 'Link Pending',
          linkedAfterRequest
              ? 'Wallet address linked to Monerium successfully.'
              : 'Link request was accepted, but Monerium confirmation is still pending. Check again shortly.',
          backgroundColor: linkedAfterRequest
              ? Theme.of(context).colorScheme.green
              : Colors.orange.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } catch (e) {
        if (!isMounted()) return;
        Get.snackbar(
          'Link Error',
          userFriendlyMoneriumError(e),
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } finally {
        if (isMounted()) {
          isConnectingMonerium.value = false;
        }
      }
    }

    Future<void> handleRequestIban() async {
      if (!isMounted()) return;

      final user = userController.user.value;
      final walletAddress = metamaskWalletAddress.value?.trim();
      final email = user.email.trim();

      if (walletAddress == null || walletAddress.isEmpty) {
        Get.snackbar(
          'Wallet Required',
          'Connect your wallet first before requesting an IBAN.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      if (email.isEmpty) {
        Get.snackbar(
          'Email Missing',
          'User email is required to continue IBAN request.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      isConnectingMonerium.value = true;

      try {
        final userId = resolveMoneriumUserId();
        final session = await MoneriumService.getStoredSession(userId: userId);
        final hasSessionToken =
            (session?['accessToken']?.toString().trim().isNotEmpty ?? false);

        if (!hasSessionToken) {
          if (!isMounted()) return;
          Get.snackbar(
            'Monerium Required',
            'Connect Monerium and link your address before requesting an IBAN.',
            backgroundColor: Colors.orange.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          return;
        }

        final linked = await isAddressLinkedOnMonerium(
          userId: userId,
          walletAddress: walletAddress,
        );
        if (!linked) {
          if (!isMounted()) return;
          Get.snackbar(
            'Link Required',
            'Link this wallet address on Monerium before requesting an IBAN.',
            backgroundColor: Colors.orange.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
          return;
        }

        final requestResponse = await MoneriumService.requestIban(
          userId: userId,
          address: walletAddress,
        );

        final ibans = await refreshMoneriumIbansNow(
          userId: userId,
          walletAddress: walletAddress,
        );
        final alreadyExists = requestResponse['alreadyExists'] == true;

        if (isMounted()) {
          moneriumIbans.value = ibans;
          isMoneriumConnected.value = true;
          isAddressLinked.value = true;
          await MoneriumService.setAddressLinked(
            userId: userId,
            linked: true,
          );
          if (ibans.isNotEmpty) {
            await paymentSetupController.markIbanReady();
          } else {
            await paymentSetupController.refresh();
          }
        }

        if (!isMounted()) return;
        Get.snackbar(
          alreadyExists ? 'IBAN Already Exists' : 'IBAN Request Submitted',
          ibans.isNotEmpty
              ? 'Slickbills/Monerium iban found'
              : (alreadyExists
                  ? 'Monerium reports an existing IBAN. It may appear after a short refresh delay.'
                  : 'Your IBAN request was accepted. It may take a few seconds to appear.'),
          backgroundColor: ibans.isNotEmpty
              ? Theme.of(context).colorScheme.green
              : Colors.orange.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } catch (e) {
        if (!isMounted()) return;
        Get.snackbar(
          'IBAN Request Error',
          userFriendlyMoneriumError(e),
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } finally {
        if (isMounted()) {
          isConnectingMonerium.value = false;
        }
      }
    }

    Future<void> loadMoneriumConnectionStatus() async {
      try {
        final userId = resolveMoneriumUserId();
        if (userId.isEmpty || userId == '0') {
          return;
        }

        final hasSession =
            await MoneriumService.hasActiveSession(userId: userId);
        var linked = await MoneriumService.isAddressLinkedFlag(userId: userId);

        if (hasSession && metamaskWalletAddress.value != null) {
          final walletAddress = metamaskWalletAddress.value!.trim();
          if (walletAddress.isNotEmpty) {
            try {
              linked = await isAddressLinkedOnMonerium(
                userId: userId,
                walletAddress: walletAddress,
              );
              await MoneriumService.setAddressLinked(
                userId: userId,
                linked: linked,
              );
            } catch (_) {
              // Keep local flag if live lookup fails.
            }
          }
        }

        await refreshMoneriumIbansNow(
          userId: userId,
          walletAddress: metamaskWalletAddress.value,
        );

        if (!isMounted()) return;
        isMoneriumConnected.value = hasSession || moneriumIbans.value.isNotEmpty;
        isAddressLinked.value = linked || moneriumIbans.value.isNotEmpty;
        await paymentSetupController.refresh();
      } catch (e) {
        debugPrint('[WalletConnectUI] failed to load Monerium status: $e');
      }
    }

    Future<void> showWalletActionsSheet() async {
      await showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Wallet & Monerium Actions',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: isConnectingMetamask.value
                        ? null
                        : () async {
                            Navigator.of(sheetContext).pop();
                            final provider = await pickWeb3AuthProvider();
                            if (provider == null || provider.isEmpty) {
                              return;
                            }
                            await handleConnectMetamask(
                              loginProvider: provider,
                            );
                          },
                    child: Text(
                      metamaskWalletAddress.value == null
                          ? 'Connect Web3Auth Wallet'
                          : 'Reconnect Web3Auth Wallet',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: isConnectingMonerium.value
                        ? null
                        : () async {
                            Navigator.of(sheetContext).pop();
                            await handleMoneriumConnect(
                              forceBrowserReconnect: true,
                            );
                          },
                    child: const Text('Reconnect Monerium'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: isConnectingMonerium.value
                        ? null
                        : () async {
                            Navigator.of(sheetContext).pop();
                            await handleLinkAddressOnly();
                          },
                    child: const Text('Link Address'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    Future<void> getPendingSendingSum() async {
      try {
        var response = await sentInvoicesClass.getPendingInvoicesSum();
        if (isMounted()) {
          pendingSending.value = response;
        }
      } catch (e) {
        print('Error fetching pending sending: $e');
      }
    }

    Future<void> getPendingReceivedSum() async {
      try {
        var response = await receivedInvoicesClass.getPendingInvoicesSum();
        if (isMounted()) {
          pendingReceived.value = response;
        }
      } catch (e) {
        print('Error fetching pending received: $e');
      }
    }

    Future<void> refreshSavedMetamaskAddress() async {
      final previousAddress = userController.user.value.metamaskWalletAddress;
      final address = await userController.getMetamaskWalletAddress();
      if (!isMounted()) return;
      if (address != null && address.isNotEmpty) {
        metamaskWalletAddress.value = address;
        await resetMoneriumStateIfWalletChanged(
          previousAddress: previousAddress,
          nextAddress: address,
        );
      }
    }

    Future<void> syncMetamaskFromWeb3AuthSession() async {
      try {
        final sessionAddress = await MetamaskWalletService.getWalletAddress();
        if (sessionAddress == null || sessionAddress.isEmpty) {
          return;
        }

        final currentAddress = userController.user.value.metamaskWalletAddress;
        if (currentAddress == sessionAddress) {
          metamaskWalletAddress.value = sessionAddress;
          return;
        }

        final updated =
            await userController.updateMetamaskWalletAddress(sessionAddress);
        if (updated && isMounted()) {
          metamaskWalletAddress.value = sessionAddress;
          await resetMoneriumStateIfWalletChanged(
            previousAddress: currentAddress,
            nextAddress: sessionAddress,
          );
        }
      } catch (e) {
        print('Error syncing MetaMask from Web3Auth session: $e');
      }
    }

    String formatAmount(double? amount) {
      if (amount == null) return '0.00';
      return amount.toStringAsFixed(2);
    }

    String shortAddress(String address) {
      if (address.length < 12) return address;
      return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
    }

    String extractIbanText(dynamic ibanRow) {
      if (ibanRow is Map<String, dynamic>) {
        final iban = ibanRow['iban'];
        if (iban is String && iban.trim().isNotEmpty) {
          return iban.trim();
        }
      }
      return 'Unknown IBAN';
    }

    String extractIbanMeta(dynamic ibanRow) {
      if (ibanRow is! Map<String, dynamic>) {
        return '';
      }

      final chain = ibanRow['chain']?.toString().trim();
      final address = ibanRow['address']?.toString().trim();
      final segments = <String>[];

      if (chain != null && chain.isNotEmpty) {
        segments.add(chain);
      }
      if (address != null && address.isNotEmpty) {
        segments.add(shortAddress(address));
      }

      return segments.join(' • ');
    }

    String? extractIbanAccountHolder(dynamic ibanRow) {
      final accountHolder = getMoneriumAccountHolderFromRow(ibanRow);
      if (accountHolder == null || accountHolder.trim().isEmpty) {
        return null;
      }
      return accountHolder.trim();
    }

    useEffect(() {
      getPendingSendingSum();
      getPendingReceivedSum();
      refreshSavedMetamaskAddress();
      syncMetamaskFromWeb3AuthSession();
      loadMoneriumConnectionStatus();
      metamaskWalletAddress.value =
          userController.user.value.metamaskWalletAddress;
      return null;
    }, []);

    final hasMoneriumIban =
        moneriumIbans.value.isNotEmpty || setupComplete.value;

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
              Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.ethereum,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Web3Auth Wallet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // MetaMask wallet connect/save
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.ethereum,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        metamaskWalletAddress.value == null
                            ? 'Web3Auth wallet not connected'
                            : 'Wallet: ${shortAddress(metamaskWalletAddress.value!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    hasMoneriumIban
                        ? IconButton(
                            onPressed: showWalletActionsSheet,
                            icon: const Icon(Icons.tune, color: Colors.white),
                            tooltip: 'Manage wallet actions',
                          )
                        : Text(
                            metamaskWalletAddress.value == null
                                ? 'Step 1'
                                : 'Done',
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.white.withOpacity(0.85),
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                  ],
                ),
              ),

              if (!hasMoneriumIban) ...[
                const SizedBox(height: 16),
                Text(
                  'Payment setup',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                _buildSetupStep(
                  context: context,
                  stepNumber: 1,
                  title: 'Connect wallet',
                  subtitle: metamaskWalletAddress.value == null
                      ? 'Attach your Web3Auth / MetaMask wallet'
                      : 'Wallet connected',
                  isDone: metamaskWalletAddress.value != null,
                  isActive: metamaskWalletAddress.value == null,
                  isEnabled: true,
                  isLoading: isConnectingMetamask.value,
                  buttonLabel: metamaskWalletAddress.value == null
                      ? 'Connect'
                      : 'Reconnect',
                  onPressed: isConnectingMetamask.value
                      ? null
                      : () async {
                          final provider = await pickWeb3AuthProvider();
                          if (provider == null || provider.isEmpty) {
                            return;
                          }
                          await handleConnectMetamask(loginProvider: provider);
                        },
                ),
                _buildSetupStep(
                  context: context,
                  stepNumber: 2,
                  title: 'Connect Monerium',
                  subtitle: isMoneriumConnected.value
                      ? 'Monerium account connected'
                      : 'Sign in to Monerium (no wallet signature yet)',
                  isDone: isMoneriumConnected.value,
                  isActive: metamaskWalletAddress.value != null &&
                      !isMoneriumConnected.value,
                  isEnabled: metamaskWalletAddress.value != null &&
                      !isConnectingMonerium.value,
                  isLoading: isConnectingMonerium.value &&
                      !isMoneriumConnected.value,
                  buttonLabel: isMoneriumConnected.value
                      ? 'Reconnect'
                      : 'Connect Monerium',
                  onPressed: metamaskWalletAddress.value == null ||
                          isConnectingMonerium.value
                      ? null
                      : () => handleMoneriumConnect(
                            forceBrowserReconnect: isMoneriumConnected.value,
                          ),
                ),
                _buildSetupStep(
                  context: context,
                  stepNumber: 3,
                  title: 'Link address',
                  subtitle: isAddressLinked.value
                      ? 'Wallet address linked on Monerium'
                      : 'Sign a message to prove wallet ownership',
                  isDone: isAddressLinked.value,
                  isActive: isMoneriumConnected.value && !isAddressLinked.value,
                  isEnabled: isMoneriumConnected.value &&
                      !isConnectingMonerium.value,
                  isLoading: isConnectingMonerium.value &&
                      isMoneriumConnected.value &&
                      !isAddressLinked.value,
                  buttonLabel: 'Link Address',
                  onPressed: !isMoneriumConnected.value ||
                          isConnectingMonerium.value
                      ? null
                      : handleLinkAddressOnly,
                ),
                _buildSetupStep(
                  context: context,
                  stepNumber: 4,
                  title: 'Request IBAN',
                  subtitle: isAddressLinked.value
                      ? 'Request your Monerium IBAN for payments'
                      : 'Available after your address is linked',
                  isDone: false,
                  isActive: isAddressLinked.value,
                  isEnabled:
                      isAddressLinked.value && !isConnectingMonerium.value,
                  isLoading: isConnectingMonerium.value && isAddressLinked.value,
                  buttonLabel: 'Request IBAN',
                  onPressed: !isAddressLinked.value || isConnectingMonerium.value
                      ? null
                      : handleRequestIban,
                  isLast: true,
                ),
              ],

              if (metamaskWalletAddress.value != null &&
                  moneriumIbans.value.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monerium IBANs (${moneriumIbans.value.length})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...moneriumIbans.value.map((ibanRow) {
                        final ibanText = extractIbanText(ibanRow);
                        final metaText = extractIbanMeta(ibanRow);
                        final accountHolderText =
                            extractIbanAccountHolder(ibanRow);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ibanText,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                if (accountHolderText != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Account holder: $accountHolderText',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                                if (metaText.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Monerium (LHV)${metaText.isNotEmpty ? ' • $metaText' : ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 11,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // ✅ Pending Transactions Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .lightGreen
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .lightGreen
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: Theme.of(context).colorScheme.lightGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'lbl_WaitingForPayment'.tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.dark,
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '€${formatAmount(pendingSending.value)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.dark,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.yellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          Theme.of(context).colorScheme.yellow.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.pending_actions,
                            color: Theme.of(context).colorScheme.yellow,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'lbl_PendingToPay'.tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.dark,
                                    fontSize: 11,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '€${formatAmount(pendingReceived.value)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.dark,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _buildSetupStep({
  required BuildContext context,
  required int stepNumber,
  required String title,
  required String subtitle,
  required bool isDone,
  required bool isActive,
  required bool isEnabled,
  required String buttonLabel,
  required VoidCallback? onPressed,
  bool isLoading = false,
  bool isLast = false,
}) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  final bool canPress = isEnabled && onPressed != null && !isLoading;

  return Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isActive || isDone ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? Colors.white.withOpacity(0.55)
              : isActive
                  ? Colors.white.withOpacity(0.35)
                  : Colors.white.withOpacity(0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDone
                  ? colorScheme.green
                  : isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: isDone
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: isActive ? colorScheme.blue : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canPress ? onPressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withOpacity(0.35),
                      foregroundColor: colorScheme.blue,
                      disabledForegroundColor: colorScheme.blue.withOpacity(0.45),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

