import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/get.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/getx_controllers/current_bank_controller.dart';
import 'package:slickbill/feature_auth/getx_controllers/user_controller.dart';

class UserInfo extends HookWidget {
  UserInfo({super.key});
  UserController userController = Get.find();
  CurrentBankController currentBankController =
      Get.put(CurrentBankController());

  @override
  Widget build(BuildContext context) {
    // Placeholder for user info widget
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.darkerBlue,
            Theme.of(context).colorScheme.lighterBlue,
          ],
          stops: const [0.0, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.darkerBlue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Enhanced Avatar with glow effect
            Stack(
              alignment: Alignment.center,
              children: [
                // Glow effect
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      (userController.user.value.fullName?.isNotEmpty == true
                              ? userController.user.value.fullName![0]
                              : userController
                                          .user.value.firstName?.isNotEmpty ==
                                      true
                                  ? userController.user.value.firstName![0]
                                  : "U")
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Name with enhanced styling
            Text(
              userController.user.value.fullName ??
                  userController.user.value.firstName ??
                  "No user",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Username with badge-like styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.alternate_email,
                    color: Colors.white.withOpacity(0.9),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    userController.user.value.username,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Optional: Add user type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: userController.user.value.isPrivate
                    ? Theme.of(context).colorScheme.lightGreen.withOpacity(0.2)
                    : Theme.of(context).colorScheme.yellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    userController.user.value.isPrivate
                        ? Icons.person
                        : Icons.business,
                    color: userController.user.value.isPrivate
                        ? Theme.of(context).colorScheme.lightGreen
                        : Theme.of(context).colorScheme.yellow,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    userController.user.value.isPrivate
                        ? 'Private'
                        : 'Business',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: userController.user.value.isPrivate
                              ? Theme.of(context).colorScheme.lightGreen
                              : Theme.of(context).colorScheme.yellow,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
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
}
