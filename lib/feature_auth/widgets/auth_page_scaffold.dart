import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:slickbill/shared_widgets/sb_page_background.dart';
import 'package:slickbill/shared_widgets/sb_surface_card.dart';
import 'package:slickbill/theme/sb_colors.dart';

class AuthPageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool isLoading;

  const AuthPageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SbPageBackground(
          child: SafeArea(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: SbColors.deepNavy),
                  )
                : GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final minBodyHeight =
                            (constraints.maxHeight - 40).clamp(0.0, double.infinity);
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: minBodyHeight,
                                maxWidth: 440,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const AuthBrandMark(),
                                  const SizedBox(height: 28),
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: text.headlineLarge?.copyWith(
                                      color: SbColors.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    subtitle,
                                    textAlign: TextAlign.center,
                                    style: text.bodyLarge?.copyWith(
                                      color: SbColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  SbSurfaceCard(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      22,
                                      20,
                                      20,
                                    ),
                                    child: child,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: SbColors.surfaceLowest,
            borderRadius: BorderRadius.circular(SbRadii.lg),
            boxShadow: SbShadows.cardSoft,
            border: Border.all(color: SbColors.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Image.asset(
            'assets/logo_icon_big.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.receipt_long_rounded,
              color: SbColors.deepNavy,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Slick',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: SbColors.deepNavy,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
              ),
              TextSpan(
                text: 'Bills',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: SbColors.secondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: SbColors.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'lbl_AuthOr'.tr,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: SbColors.outline,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const Expanded(child: Divider(color: SbColors.outlineVariant)),
      ],
    );
  }
}

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      enableSuggestions: !obscure,
      cursorColor: SbColors.deepNavy,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: SbColors.onSurface,
          ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: SbColors.onSurfaceVariant,
            ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: SbColors.deepNavy,
          foregroundColor: SbColors.onPrimary,
          disabledBackgroundColor: SbColors.outlineVariant,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SbRadii.md),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SbColors.onPrimary,
                ),
              )
            : Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: SbColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
      ),
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onTap;

  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodyMedium;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$prompt ',
            style: text?.copyWith(color: SbColors.onSurfaceVariant),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                action,
                style: text?.copyWith(
                  color: SbColors.deepNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
