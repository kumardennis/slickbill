import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:slickbill/shared_widgets/sb_money_text.dart';
import 'package:slickbill/shared_widgets/sb_page_background.dart';
import 'package:slickbill/shared_widgets/sb_surface_card.dart';
import 'package:slickbill/shared_widgets/sb_trust_banner.dart';
import 'package:slickbill/theme/sb_colors.dart';

class PublicInvoicePage extends StatelessWidget {
  final Widget child;
  final Widget? topBar;
  final bool showAppBar;
  final String title;
  final VoidCallback? onBack;

  const PublicInvoicePage({
    super.key,
    required this.child,
    this.topBar,
    this.showAppBar = false,
    this.title = 'SlickBills',
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: SbColors.surface.withValues(alpha: 0.72),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: onBack != null,
              leading: onBack == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: SbColors.onSurface,
                      onPressed: onBack,
                    ),
              title: Row(
                children: [
                  Image.asset(
                    'assets/logo_icon_big.png',
                    height: 24,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.receipt_long_rounded,
                      color: SbColors.deepNavy,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: SbColors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            )
          : null,
      body: SbPageBackground(
        child: Column(
          children: [
            if (topBar != null) topBar!,
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class PublicInvoiceAppPromptBar extends StatelessWidget {
  final VoidCallback onOpenApp;
  final VoidCallback? onGoHome;

  const PublicInvoiceAppPromptBar({
    super.key,
    required this.onOpenApp,
    this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SbColors.surfaceLowest.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Image.asset(
              'assets/logo_icon_big.png',
              height: 22,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.receipt_long_rounded,
                color: SbColors.deepNavy,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Have the app?',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: SbColors.onSurface,
                    ),
              ),
            ),
            TextButton(
              onPressed: onOpenApp,
              child: const Text('Open in app'),
            ),
            if (onGoHome != null)
              TextButton(
                onPressed: onGoHome,
                child: const Text('Home'),
              ),
          ],
        ),
      ),
    );
  }
}

class PublicInvoiceHeroCard extends StatelessWidget {
  final double amount;
  final String? description;
  final String statusLabel;
  final Color statusColor;
  final Widget? extra;

  const PublicInvoiceHeroCard({
    super.key,
    required this.amount,
    required this.statusLabel,
    required this.statusColor,
    this.description,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SbSpace.lg),
      decoration: BoxDecoration(
        gradient: SbGradients.card(tint: SbColors.electricCyan),
        borderRadius: BorderRadius.circular(SbRadii.md),
        boxShadow: SbShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payment request',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: SbColors.onSurfaceVariant,
                      ),
                ),
              ),
              SbStatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          SbMoneyText(
            amount: amount,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: SbColors.onSurface,
                    height: 1.45,
                  ),
            ),
          ],
          if (extra != null) extra!,
        ],
      ),
    );
  }
}

class PublicInvoiceDetailsCard extends StatelessWidget {
  final List<Widget> children;

  const PublicInvoiceDetailsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SbSpace.lg),
      decoration: BoxDecoration(
        color: SbColors.surfaceLowest,
        borderRadius: BorderRadius.circular(SbRadii.md),
        boxShadow: SbShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: SbColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class PublicInvoiceDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool copyable;

  const PublicInvoiceDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.highlight = false,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: SbColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: highlight ? SbColors.error : SbColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (copyable) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                Get.snackbar(
                  'Copied',
                  '$label copied',
                  snackPosition: SnackPosition.BOTTOM,
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 2),
                );
              },
              borderRadius: BorderRadius.circular(SbRadii.sm),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: SbColors.secondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PublicInvoiceLinkRow extends StatelessWidget {
  final String url;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  const PublicInvoiceLinkRow({
    super.key,
    required this.url,
    required this.onOpen,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: SbColors.electricCyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(SbRadii.sm),
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(SbRadii.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        size: 16,
                        color: SbColors.deepNavy,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: SbColors.deepNavy,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 16),
            color: SbColors.successGreen,
            style: IconButton.styleFrom(
              backgroundColor: SbColors.successGreen.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class PublicInvoiceActions extends StatelessWidget {
  final List<Widget> children;

  const PublicInvoiceActions({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SbTrustBanner(),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

Future<bool> showPublicInvoiceConfirm({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: SbColors.surfaceLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SbRadii.md),
            ),
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: SbColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            content: Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SbColors.onSurfaceVariant,
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: SbColors.onSurfaceVariant),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      ) ??
      false;
}
