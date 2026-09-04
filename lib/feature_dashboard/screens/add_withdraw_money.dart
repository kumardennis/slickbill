import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/app_lock_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/feature_auth/models/user_model.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/payment_setup_controller.dart';
import 'package:slickbill/feature_dashboard/screens/add_ibans.dart';
import 'package:slickbill/shared_widgets/custom_appbar.dart';

class AddWithdrawMoneyScreen extends HookWidget {
  final bool startOnWithdraw;

  const AddWithdrawMoneyScreen({
    super.key,
    this.startOnWithdraw = false,
  });

  @override
  Widget build(BuildContext context) {
    final tabController = useTabController(
      initialLength: 2,
      initialIndex: startOnWithdraw ? 1 : 0,
    );
    final userController = Get.find<UserController>();
    final paymentSetupController = Get.put(PaymentSetupController());

    final isLoading = useState(false);
    final isWithdrawing = useState(false);
    final moneriumIbans = useState<List<dynamic>>([]);
    final eurBalance = useState<double?>(null);
    final selectedIban = useState<String?>(null);
    final amountController = useTextEditingController();

    String resolveUserId(ClientUserModel user) {
      return PaymentSetupController.resolveMoneriumUserId(user);
    }

    String normalizeIban(String value) {
      return value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    }

    String? extractMoneriumIban(dynamic row) {
      if (row is String && row.trim().isNotEmpty) {
        return row.trim();
      }
      if (row is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(row);
      for (final candidate in [
        map['iban'],
        map['ibanNumber'],
        map['iban_number'],
      ]) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
        if (candidate is Map) {
          final nested = candidate['iban'] ?? candidate['ibanNumber'];
          if (nested is String && nested.trim().isNotEmpty) {
            return nested.trim();
          }
        }
      }
      return null;
    }

    String? extractAccountHolder(dynamic row) {
      if (row is! Map) {
        return null;
      }
      final map = Map<String, dynamic>.from(row);
      for (final candidate in [
        map['accountHolderName'],
        map['account_holder_name'],
        map['accountHolder'],
        map['name'],
      ]) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
      return null;
    }

    String formatIban(String iban) {
      final compact = normalizeIban(iban);
      final buffer = StringBuffer();
      for (var i = 0; i < compact.length; i++) {
        if (i > 0 && i % 4 == 0) {
          buffer.write(' ');
        }
        buffer.write(compact[i]);
      }
      return buffer.toString();
    }

    bool isMoneriumBank(BankAccount account) {
      return account.bankName.trim().toLowerCase().contains('monerium');
    }

    List<BankAccount> savedExternalBanks({
      required ClientUserModel user,
      required Set<String> moneriumIbanValues,
    }) {
      final accounts = <BankAccount>[...(user.ibans ?? const [])];
      final primary = user.iban?.trim() ?? '';
      if (primary.isNotEmpty &&
          !accounts.any((account) => normalizeIban(account.iban) == normalizeIban(primary))) {
        accounts.add(
          BankAccount(
            iban: primary,
            bankName: user.bankName ?? '',
            bankAccountName: user.bankAccountName,
            isPrimary: true,
          ),
        );
      }

      return accounts
          .where((account) {
            final iban = normalizeIban(account.iban);
            if (iban.isEmpty) {
              return false;
            }
            if (isMoneriumBank(account)) {
              return false;
            }
            return !moneriumIbanValues.contains(iban);
          })
          .toList(growable: false);
    }

    double? parseEurAmount(dynamic data) {
      if (data is! Map<String, dynamic>) {
        return null;
      }
      final balances = data['balances'];
      if (balances is! List) {
        return null;
      }
      for (final row in balances) {
        if (row is! Map<String, dynamic>) {
          continue;
        }
        final currency = (row['currency'] ?? row['ticker'] ?? row['symbol'])
            ?.toString()
            .toUpperCase();
        if (currency != 'EUR' && currency != 'EURE') {
          continue;
        }
        return double.tryParse(
          (row['amount'] ?? row['balance'] ?? row['available'] ?? row['value'])
                  ?.toString()
                  .replaceAll(',', '.') ??
              '',
        );
      }
      return null;
    }

    Future<void> loadMoneriumData() async {
      final user = userController.user.value;
      final walletAddress = user.metamaskWalletAddress?.trim() ?? '';
      if (walletAddress.isEmpty) {
        moneriumIbans.value = const [];
        eurBalance.value = null;
        return;
      }

      isLoading.value = true;
      try {
        final userId = resolveUserId(user);
        await MoneriumService.hasActiveSession(userId: userId);
        final ibansResponse = await MoneriumService.getIbans(userId: userId);
        final ibans = MoneriumService.extractIbansFromResponse(ibansResponse);
        moneriumIbans.value = ibans;

        if (ibans.isEmpty) {
          eurBalance.value = null;
          return;
        }

        var chain = 'polygon';
        for (final row in ibans) {
          if (row is Map && row['chain']?.toString().trim().isNotEmpty == true) {
            chain = row['chain'].toString().trim();
            break;
          }
        }

        final balanceResponse = await MoneriumService.getBalances(
          userId: userId,
          address: walletAddress,
          chain: chain,
        );
        eurBalance.value = parseEurAmount(balanceResponse['data']);
      } catch (error) {
        debugPrint('[AddWithdraw] load failed: $error');
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      loadMoneriumData();
      return null;
    }, []);

    Future<void> copyText(String value, String label) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) {
        return;
      }
      Get.snackbar(
        'Copied',
        '$label copied.',
        backgroundColor: Theme.of(context).colorScheme.green.withOpacity(0.12),
        colorText: Theme.of(context).colorScheme.green,
        duration: const Duration(seconds: 2),
      );
    }

    Future<void> submitWithdraw(BankAccount destination) async {
      final user = userController.user.value;
      final amount = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
      final available = eurBalance.value ?? 0;
      final walletAddress = user.metamaskWalletAddress?.trim() ?? '';
      final email = user.email.trim();
      final userId = resolveUserId(user);

      if (walletAddress.isEmpty) {
        Get.snackbar(
          'Wallet required',
          'Connect your wallet before withdrawing.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }
      if (amount == null || amount <= 0) {
        Get.snackbar(
          'Amount required',
          'Enter how much EUR to withdraw.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }
      if (amount > available) {
        Get.snackbar(
          'Not enough balance',
          'You can withdraw up to €${available.toStringAsFixed(2)}.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
        return;
      }

      final confirmed = await AppLockController.confirmSensitiveAction(
        reason: 'lbl_ConfirmWithdraw'.trParams({
          'amount': '€${amount.toStringAsFixed(2)}',
        }),
      );
      if (!confirmed) return;

      isWithdrawing.value = true;
      try {
        await MoneriumService.ensureConnected(
          userId: userId,
          email: email,
        );
        await paymentSetupController.markMoneriumConnected();

        final normalizedIban = normalizeIban(destination.iban);
        final countryCode = RegExp(r'^[A-Z]{2}').hasMatch(normalizedIban)
            ? normalizedIban.substring(0, 2)
            : 'EE';
        final holder = (destination.bankAccountName ?? '').trim();
        final fallbackName = [
          user.firstName,
          user.lastName,
        ].whereType<String>().map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
        final name = holder.isNotEmpty
            ? holder
            : (fallbackName.isNotEmpty ? fallbackName : user.username);
        final nameParts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
        final firstName = nameParts.isNotEmpty ? nameParts.first : 'Account';
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Holder';
        final nowUtc = DateTime.now().toUtc();
        final timestamp =
            '${nowUtc.year.toString().padLeft(4, '0')}-${nowUtc.month.toString().padLeft(2, '0')}-${nowUtc.day.toString().padLeft(2, '0')}T${nowUtc.hour.toString().padLeft(2, '0')}:${nowUtc.minute.toString().padLeft(2, '0')}:${nowUtc.second.toString().padLeft(2, '0')}Z';
        final amountText = amount.toStringAsFixed(2);

        final response = await MoneriumService.createWithdrawOrderWithSignature(
          userId: userId,
          walletAddress: walletAddress,
          order: {
            'kind': 'redeem',
            'currency': 'eur',
            'message': 'Send EUR $amountText to $normalizedIban at $timestamp',
            'counterpart': {
              'identifier': {
                'standard': 'iban',
                'iban': normalizedIban,
              },
              'details': {
                'firstName': firstName,
                'lastName': lastName,
                'country': countryCode,
              },
            },
            'amount': amountText,
            'memo': 'SlickBills withdraw',
            'referenceNumber': 'wd${nowUtc.millisecondsSinceEpoch}'.substring(0, 14),
          },
        );

        final orderId = MoneriumService.extractOrderId(response);
        var state = MoneriumService.extractOrderState(response);
        if (orderId != null && orderId.isNotEmpty) {
          for (var i = 0; i < 6; i++) {
            if (state == 'processed' || state == 'rejected') {
              break;
            }
            await Future.delayed(const Duration(seconds: 2));
            final check = await MoneriumService.recheckOrderById(
              userId: userId,
              orderId: orderId,
            );
            state = check['state']?.toString();
          }
        }

        if (state == 'rejected') {
          Get.snackbar(
            'Withdrawal rejected',
            'Monerium rejected this transfer. Check the amount and try again.',
            backgroundColor: Theme.of(context).colorScheme.red,
            colorText: Colors.white,
          );
          return;
        }

        amountController.clear();
        await loadMoneriumData();
        Get.snackbar(
          state == 'processed' ? 'Withdrawal sent' : 'Withdrawal submitted',
          state == 'processed'
              ? 'EUR is on the way to ${destination.bankName}.'
              : 'Monerium is processing the SEPA transfer to your saved account.',
          backgroundColor: Theme.of(context).colorScheme.green.withOpacity(0.12),
          colorText: Theme.of(context).colorScheme.green,
          duration: const Duration(seconds: 4),
        );
      } catch (error) {
        debugPrint('[AddWithdraw] withdraw failed: $error');
        Get.snackbar(
          'Withdrawal failed',
          'Could not complete the transfer. Reconnect Monerium and try again.',
          backgroundColor: Theme.of(context).colorScheme.red,
          colorText: Colors.white,
        );
      } finally {
        isWithdrawing.value = false;
      }
    }

    Widget infoCard({required Widget child}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.light,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.lightGray.withOpacity(0.55),
          ),
        ),
        child: child,
      );
    }

    TextStyle? onLight(
      TextStyle? style, {
      required Color color,
      FontWeight? weight,
    }) {
      return style?.copyWith(
        color: color,
        fontWeight: weight ?? style.fontWeight,
      );
    }

    return Scaffold(
      appBar: CustomAppbar(
        title: 'Add & withdraw',
        appbarIcon: null,
        tabBar: TabBar(
          controller: tabController,
          indicatorColor: Theme.of(context).colorScheme.blue,
          labelColor: Theme.of(context).colorScheme.blue,
          unselectedLabelColor: Theme.of(context).colorScheme.gray,
          labelStyle: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Add money'),
            Tab(text: 'Withdraw'),
          ],
        ),
      ),
      body: Obx(() {
        final colors = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        final user = userController.user.value;
        final moneriumIbanValues = moneriumIbans.value
            .map(extractMoneriumIban)
            .whereType<String>()
            .map(normalizeIban)
            .where((iban) => iban.isNotEmpty)
            .toSet();
        final liveIban = moneriumIbans.value
            .map(extractMoneriumIban)
            .whereType<String>()
            .firstWhere((iban) => iban.trim().isNotEmpty, orElse: () => '');
        final holder = moneriumIbans.value
                .map(extractAccountHolder)
                .whereType<String>()
                .firstWhere((name) => name.trim().isNotEmpty, orElse: () => '')
                .trim();
        final banks = savedExternalBanks(
          user: user,
          moneriumIbanValues: moneriumIbanValues,
        );
        final effectiveSelectedIban = selectedIban.value ??
            (banks.isNotEmpty ? banks.first.iban : null);

        return TabBarView(
          controller: tabController,
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  'Send EUR from your bank to this IBAN. Monerium mints it into your SlickBills balance.',
                  style: onLight(text.bodyMedium, color: colors.darkGray),
                ),
                const SizedBox(height: 16),
                if (isLoading.value && liveIban.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (liveIban.isEmpty)
                  infoCard(
                    child: Text(
                      'Your Monerium IBAN is not available yet. Finish payment setup first.',
                      style: onLight(text.bodyMedium, color: colors.darkerBlue),
                    ),
                  )
                else
                  infoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monerium IBAN',
                          style: onLight(
                            text.labelLarge,
                            color: colors.blue,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatIban(liveIban),
                          style: onLight(
                            text.titleMedium,
                            color: colors.darkerBlue,
                            weight: FontWeight.w800,
                          )?.copyWith(letterSpacing: 0.4),
                        ),
                        if (holder.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Account holder: $holder',
                            style: onLight(text.bodySmall, color: colors.darkGray),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Bank: Monerium (LHV)',
                          style: onLight(text.bodySmall, color: colors.darkGray),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                copyText(normalizeIban(liveIban), 'IBAN'),
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: colors.blue,
                            ),
                            label: Text(
                              'Copy IBAN',
                              style: onLight(
                                text.labelLarge,
                                color: colors.blue,
                                weight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.blue,
                              side: BorderSide(color: colors.blue),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                infoCard(
                  child: Text(
                    'Use a regular SEPA transfer. There is no amount to submit in the app — whatever arrives is added to your balance.',
                    style: onLight(text.bodySmall, color: colors.darkGray),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading.value ? null : loadMoneriumData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isLoading.value ? 'Refreshing…' : 'Refresh balance',
                    ),
                  ),
                ),
                if (eurBalance.value != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Current balance: €${eurBalance.value!.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: onLight(
                      text.bodyMedium,
                      color: colors.darkerBlue,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  'Send EUR from SlickBills to one of your saved bank accounts.',
                  style: onLight(text.bodyMedium, color: colors.darkGray),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available: €${(eurBalance.value ?? 0).toStringAsFixed(2)}',
                  style: onLight(
                    text.titleMedium,
                    color: colors.blue,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: onLight(
                    text.titleMedium,
                    color: colors.darkerBlue,
                    weight: FontWeight.w600,
                  ),
                  cursorColor: colors.blue,
                  decoration: InputDecoration(
                    labelText: 'Amount (EUR)',
                    prefixText: '€ ',
                    labelStyle: onLight(text.bodySmall, color: colors.darkGray),
                    prefixStyle: onLight(
                      text.titleMedium,
                      color: colors.darkerBlue,
                      weight: FontWeight.w700,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.lightGray),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Saved bank accounts',
                  style: onLight(
                    text.titleSmall,
                    color: colors.darkerBlue,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                if (banks.isEmpty)
                  infoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add a personal bank account in Profile first. You can only withdraw to saved accounts, not to your Monerium IBAN.',
                          style: onLight(text.bodyMedium, color: colors.darkGray),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () async {
                              final result =
                                  await Get.to(() => const AddIbanScreen());
                              if (result == true) {
                                await userController.loadUserData();
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.blue,
                              side: BorderSide(color: colors.blue),
                            ),
                            child: const Text('Add bank account'),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...banks.map((bank) {
                    final selected =
                        normalizeIban(effectiveSelectedIban ?? '') ==
                            normalizeIban(bank.iban);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: selected
                            ? colors.lighterBlue.withOpacity(0.12)
                            : colors.light,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: selected
                                ? colors.lighterBlue.withOpacity(0.45)
                                : colors.lightGray.withOpacity(0.55),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => selectedIban.value = bank.iban,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.buildingColumns,
                                  size: 16,
                                  color: colors.blue,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bank.bankName.trim().isNotEmpty
                                            ? bank.bankName
                                            : 'Saved account',
                                        style: onLight(
                                          text.bodyMedium,
                                          color: colors.darkerBlue,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatIban(bank.iban),
                                        style: onLight(
                                          text.bodySmall,
                                          color: colors.darkGray,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: colors.blue,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isWithdrawing.value || banks.isEmpty
                        ? null
                        : () {
                            final destination = banks.firstWhere(
                              (bank) =>
                                  normalizeIban(bank.iban) ==
                                  normalizeIban(
                                    effectiveSelectedIban ?? banks.first.iban,
                                  ),
                              orElse: () => banks.first,
                            );
                            submitWithdraw(destination);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          colors.lightGray.withOpacity(0.45),
                      disabledForegroundColor: colors.darkGray,
                    ),
                    child: isWithdrawing.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Withdraw'),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}
