import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_dashboard/getx_controllers/payment_setup_controller.dart';
import 'package:slickbill/feature_dashboard/screens/profile.dart';

class PaymentSetupBanner extends StatelessWidget {
  const PaymentSetupBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final PaymentSetupController setupController =
        Get.put(PaymentSetupController());
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(() {
      final step = setupController.step.value;
      if (step == PaymentSetupStep.complete) {
        return const SizedBox.shrink();
      }

      final config = _configForStep(step, colorScheme);

      return Material(
        color: config.background,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Profile(),
              ),
            );
            await setupController.refresh();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FaIcon(
                  config.icon,
                  size: 18,
                  color: colorScheme.darkerBlue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.darkerBlue,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        config.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.darkGray,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  step == PaymentSetupStep.reconnectMonerium
                      ? 'Reconnect'
                      : 'Continue',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.lighterBlue,
                      ),
                ),
                const SizedBox(width: 4),
                FaIcon(
                  FontAwesomeIcons.chevronRight,
                  size: 12,
                  color: colorScheme.lighterBlue,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  _BannerConfig _configForStep(
    PaymentSetupStep step,
    ColorScheme colorScheme,
  ) {
    switch (step) {
      case PaymentSetupStep.connectWallet:
        return _BannerConfig(
          icon: FontAwesomeIcons.wallet,
          title: 'Connect your wallet',
          subtitle:
              'Create a new wallet, or use MetaMask / WalletConnect.',
          background: colorScheme.lighterBlue.withOpacity(0.12),
        );
      case PaymentSetupStep.connectMonerium:
        return _BannerConfig(
          icon: FontAwesomeIcons.buildingColumns,
          title: 'Set up payments',
          subtitle: 'Connect Monerium to get your IBAN.',
          background: colorScheme.yellow.withOpacity(0.18),
        );
      case PaymentSetupStep.reconnectMonerium:
        return _BannerConfig(
          icon: FontAwesomeIcons.buildingColumns,
          title: 'Reconnect Monerium',
          subtitle: 'Sign in to load your IBAN and balance.',
          background: colorScheme.yellow.withOpacity(0.18),
        );
      case PaymentSetupStep.complete:
        return _BannerConfig(
          icon: FontAwesomeIcons.check,
          title: '',
          subtitle: '',
          background: Colors.transparent,
        );
    }
  }
}

class _BannerConfig {
  final FaIconData icon;
  final String title;
  final String subtitle;
  final Color background;

  const _BannerConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
  });
}
