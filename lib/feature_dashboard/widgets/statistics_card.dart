import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/utils/money_formatter.dart';

class StatisticsCard extends StatelessWidget {
  final double? pendingAmount;
  final double? paidAmount;
  final String pendingLabel;
  final String paidLabel;

  const StatisticsCard({
    super.key,
    this.pendingAmount,
    this.paidAmount,
    required this.pendingLabel,
    required this.paidLabel,
  });

  @override
  Widget build(BuildContext context) {
    final FormatNumber formatNumber = FormatNumber();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Pending Card
          Expanded(
            child: _buildModernCard(
              context: context,
              title: pendingLabel,
              amount: pendingAmount != null
                  ? formatNumber.formatMoney(pendingAmount!)
                  : '€0.00',
              primaryColor: Theme.of(context).colorScheme.yellow,
              secondaryColor: Theme.of(context).colorScheme.lightYellow,
              icon: Icons.schedule_rounded,
              isLeft: true,
            ),
          ),

          const SizedBox(width: 12),

          // Paid Card
          Expanded(
            child: _buildModernCard(
              context: context,
              title: paidLabel,
              amount: paidAmount != null
                  ? formatNumber.formatMoney(paidAmount!)
                  : '€0.00',
              primaryColor: Theme.of(context).colorScheme.green,
              secondaryColor: Theme.of(context).colorScheme.lightGreen,
              icon: Icons.check_circle_rounded,
              isLeft: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCard({
    required BuildContext context,
    required String title,
    required String amount,
    required Color primaryColor,
    required Color secondaryColor,
    required IconData icon,
    required bool isLeft,
  }) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.1),
            secondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              top: -20,
              right: isLeft ? null : -20,
              left: isLeft ? -20 : null,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon and label row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: primaryColor.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: primaryColor,
                          size: 18,
                        ),
                      ),
                    ],
                  ),

                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        amount,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 3,
                        width: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
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
