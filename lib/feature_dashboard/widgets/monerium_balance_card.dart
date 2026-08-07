import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/models/user_model.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/payment_setup_controller.dart';

class MoneriumBalanceCard extends HookWidget {
  final ClientUserModel user;

  const MoneriumBalanceCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isFetchingBalance = useState(false);
    final balanceSummary = useState<String?>(null);
    final moneriumIbans = useState<List<dynamic>>([]);
    final PaymentSetupController paymentSetupController =
        Get.put(PaymentSetupController());

    String resolveMoneriumUserId() {
      final privateUserId = user.privateUserId;
      if (privateUserId != null && privateUserId > 0) {
        return privateUserId.toString();
      }
      return user.id.toString();
    }

    String normalizeWalletAddress(String? address) {
      if (address == null) return '';
      return address.trim().toLowerCase();
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

    String resolveMoneriumChainForBalances(List<dynamic> ibans) {
      for (final row in ibans) {
        if (row is Map<String, dynamic>) {
          final chain = row['chain']?.toString().trim();
          if (chain != null && chain.isNotEmpty) {
            return chain;
          }
        }
      }

      return const String.fromEnvironment(
        'MONERIUM_WALLET_CHAIN',
        defaultValue: '',
      );
    }

    String summarizeMoneriumBalances(dynamic data) {
      List<dynamic> rows = const [];
      if (data is Map<String, dynamic>) {
        final balances = data['balances'];
        if (balances is List) {
          rows = balances;
        }
      }

      if (rows.isEmpty) {
        return 'No balances returned.';
      }

      final parts = <String>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) {
          continue;
        }

        final currency = (row['currency'] ?? row['ticker'] ?? row['symbol'])
            ?.toString()
            .toUpperCase();
        final amount = (row['amount'] ??
                row['balance'] ??
                row['available'] ??
                row['value'])
            ?.toString();

        if (currency != null &&
            currency.isNotEmpty &&
            amount != null &&
            amount.isNotEmpty) {
          parts.add('$currency: $amount');
        }
      }

      if (parts.isEmpty) {
        return 'Balance data received.';
      }

      return parts.join(' | ');
    }

    List<String> balanceLines(String? summary) {
      if (summary == null || summary.trim().isEmpty) {
        return const [];
      }

      return summary
          .replaceAll(' | ', '\n')
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
    }

    Future<void> loadBalance({bool showFeedback = false}) async {
      final walletAddress = user.metamaskWalletAddress?.trim() ?? '';
      if (walletAddress.isEmpty) {
        moneriumIbans.value = const [];
        balanceSummary.value = null;
        return;
      }

      isFetchingBalance.value = true;
      try {
        final userId = resolveMoneriumUserId();
        final ibansResponse = await MoneriumService.getIbans(userId: userId);
        final rawIbans = MoneriumService.extractIbans(ibansResponse['data']);
        final filteredIbans = filterIbansForWallet(
          ibans: rawIbans,
          walletAddress: walletAddress,
        );
        moneriumIbans.value = filteredIbans;

        if (filteredIbans.isEmpty) {
          balanceSummary.value = null;
          return;
        }

        final chain = resolveMoneriumChainForBalances(filteredIbans);
        if (chain.isEmpty) {
          balanceSummary.value = null;
          return;
        }

        final balanceResponse = await MoneriumService.getBalances(
          userId: userId,
          address: walletAddress,
          chain: chain,
        );

        balanceSummary.value =
            summarizeMoneriumBalances(balanceResponse['data']);

        // A successful balance fetch means Monerium is fully connected.
        await paymentSetupController.markCompleteFromBalance(userId: userId);
      } catch (_) {
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to refresh Monerium balance.'),
              backgroundColor: Theme.of(context).colorScheme.red,
            ),
          );
        }
      } finally {
        isFetchingBalance.value = false;
      }
    }

    useEffect(() {
      loadBalance();
      return null;
    }, [user.id, user.privateUserId, user.metamaskWalletAddress]);

    final hasMoneriumIban = moneriumIbans.value.isNotEmpty;
    final shouldShowCard = hasMoneriumIban &&
        !(user.metamaskWalletAddress?.trim().isEmpty ?? true);

    final visibleBalanceLines = balanceLines(balanceSummary.value);
    final eurLine = visibleBalanceLines.cast<String?>().firstWhere(
          (line) => (line ?? '').toUpperCase().startsWith('EUR:'),
          orElse: () => null,
        );
    final eurAmount = eurLine != null && eurLine.contains(':')
        ? eurLine.split(':').skip(1).join(':').trim()
        : null;
    final prominentBalanceLine = (eurAmount != null && eurAmount.isNotEmpty)
        ? '€$eurAmount'
        : (visibleBalanceLines.isNotEmpty ? visibleBalanceLines.first : null);

    final card = Container(
      key: const ValueKey('monerium-balance-card'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.darkerBlue.withOpacity(0.96),
            Theme.of(context).colorScheme.blue.withOpacity(0.88),
            Theme.of(context).colorScheme.turqouise.withOpacity(0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.darkerBlue.withOpacity(0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.16),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: -24,
              top: -18,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              left: -22,
              bottom: -36,
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.euro_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Slickbills Balance',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isFetchingBalance.value
                              ? null
                              : () => loadBalance(showFeedback: true),
                          borderRadius: BorderRadius.circular(999),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                isFetchingBalance.value
                                    ? const SizedBox(
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                const SizedBox(width: 6),
                                Text(
                                  isFetchingBalance.value
                                      ? 'Refreshing'
                                      : 'Refresh',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Available EUR',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.82),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  if (isFetchingBalance.value)
                    Text(
                      prominentBalanceLine ?? '€0',
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Colors.white.withOpacity(0.72),
                                fontWeight: FontWeight.w900,
                                height: 0.95,
                              ),
                    )
                  else if (prominentBalanceLine != null)
                    Text(
                      prominentBalanceLine,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            height: 0.95,
                            letterSpacing: -0.8,
                          ),
                    )
                  else
                    Text(
                      '€ --',
                      style:
                          Theme.of(context).textTheme.displayMedium?.copyWith(
                                color: Colors.white.withOpacity(0.78),
                                fontWeight: FontWeight.w900,
                                height: 0.95,
                              ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    isFetchingBalance.value
                        ? 'Syncing latest Monerium balance'
                        : 'Live balance from your linked Monerium account',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.76),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (visibleBalanceLines.length > 1) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: visibleBalanceLines.skip(1).map((line) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            line,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withOpacity(0.92),
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: slide,
            child: child,
          ),
        );
      },
      child: shouldShowCard
          ? card
          : const SizedBox(
              key: ValueKey('monerium-balance-empty'),
            ),
    );
  }
}
