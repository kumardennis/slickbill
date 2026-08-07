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
              MaterialPageRoute(builder: (context) => const Profile()),
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
                  'Go to Profile',
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
              'Go to Profile to attach MetaMask so you can set up Monerium payments.',
          background: colorScheme.lighterBlue.withOpacity(0.12),
        );
      case PaymentSetupStep.connectMonerium:
        return _BannerConfig(
          icon: FontAwesomeIcons.buildingColumns,
          title: 'Connect Monerium',
          subtitle:
              'Go to Profile and connect Monerium to continue payment setup.',
          background: colorScheme.yellow.withOpacity(0.18),
        );
      case PaymentSetupStep.linkAddress:
        return _BannerConfig(
          icon: FontAwesomeIcons.link,
          title: 'Link your wallet address',
          subtitle:
              'Go to Profile and link your wallet address on Monerium.',
          background: colorScheme.yellow.withOpacity(0.18),
        );
      case PaymentSetupStep.requestIban:
        return _BannerConfig(
          icon: FontAwesomeIcons.moneyCheckDollar,
          title: 'Request your Monerium IBAN',
          subtitle:
              'Go to Profile and request an IBAN to finish payment setup.',
          background: colorScheme.lightYellow.withOpacity(0.55),
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
