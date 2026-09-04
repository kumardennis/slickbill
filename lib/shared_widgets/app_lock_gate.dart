import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:slickbill/feature_auth/getx_controllers/app_lock_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';
import 'package:slickbill/services/biometric_auth_service.dart';
import 'package:slickbill/theme/sb_colors.dart';

class AppLockGate extends StatelessWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  bool _isAuthRoute() {
    final route = Get.currentRoute;
    return route == '/sign-in' ||
        route == '/sign-up' ||
        route.startsWith('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return child;

    return Obx(() {
      final lock = Get.find<AppLockController>();
      lock.routeEpoch.value;
      final signedIn = Get.isRegistered<UserController>() &&
          Get.find<UserController>().user.value.id > 0;
      final showLock = signedIn && !lock.isUnlocked.value && !_isAuthRoute();

      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: showLock,
            child: ExcludeSemantics(
              excluding: showLock,
              child: child,
            ),
          ),
          if (showLock) const AppLockOverlay(),
        ],
      );
    });
  }
}

class AppLockOverlay extends StatefulWidget {
  const AppLockOverlay({super.key});

  @override
  State<AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<AppLockOverlay> {
  DeviceAuthResult? _lastResult;
  var _autoPrompted = false;

  AppLockController get _lock => Get.find<AppLockController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoPrompted) return;
      _autoPrompted = true;
      _unlock();
    });
  }

  Future<void> _unlock() async {
    final availability = await _lock.peekAvailability();
    if (!mounted) return;

    if (availability == DeviceAuthResult.unavailable) {
      setState(() => _lastResult = DeviceAuthResult.unavailable);
      return;
    }

    final result = await _lock.unlock(reason: 'lbl_UnlockToContinue'.tr);
    if (!mounted) return;
    if (result != DeviceAuthResult.success) {
      setState(() => _lastResult = result);
    }
  }

  Future<void> _signOut() async {
    if (!Get.isRegistered<UserController>()) return;
    await Get.find<UserController>().forceLogout();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final unavailable = _lastResult == DeviceAuthResult.unavailable;
    final lockedOut = _lastResult == DeviceAuthResult.lockedOut;

    return PopScope(
      canPop: false,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Material(
          color: SbColors.deepNavy,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [SbColors.deepNavy, SbColors.primary],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Image.asset(
                      'assets/logo_icon_big.png',
                      height: 64,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.receipt_long_rounded,
                        color: SbColors.electricCyan,
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SlickBills',
                      style: text.headlineMedium?.copyWith(
                        color: SbColors.onPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'lbl_UnlockToContinue'.tr,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(
                        color: SbColors.primaryFixedDim,
                      ),
                    ),
                    const Spacer(flex: 3),
                    if (unavailable) ...[
                      Text(
                        'lbl_LockRequiresDevicePasscode'.tr,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: SbColors.primaryFixedDim,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else if (lockedOut) ...[
                      Text(
                        'lbl_LockTooManyAttempts'.tr,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: SbColors.primaryFixedDim,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (!unavailable)
                      Obx(
                        () => SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed:
                                _lock.isAuthenticating.value ? null : _unlock,
                            style: FilledButton.styleFrom(
                              backgroundColor: SbColors.electricCyan,
                              foregroundColor: SbColors.deepNavy,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(SbRadii.sm),
                              ),
                            ),
                            child: Text(
                              'btn_Unlock'.tr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (!unavailable)
                      Text(
                        'lbl_UnlockHint'.tr,
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(
                          color: SbColors.primaryFixedDim.withValues(alpha: 0.8),
                        ),
                      ),
                    const SizedBox(height: 28),
                    TextButton(
                      onPressed: _signOut,
                      style: TextButton.styleFrom(
                        foregroundColor: SbColors.primaryFixedDim,
                      ),
                      child: Text('btn_SignOut'.tr),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
