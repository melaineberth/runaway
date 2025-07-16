import 'package:flutter/material.dart';
import 'package:runaway/core/helper/extensions/extensions.dart';
import 'package:runaway/core/widgets/squircle_container.dart';
import 'package:runaway/features/credits/domain/models/credit_plan.dart';

/// Card pour afficher un plan de crédits
class CreditPlanCard extends StatelessWidget {
  final CreditPlan plan;
  final VoidCallback onTap;
  final bool isSelected;

  const CreditPlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return SquircleContainer(
      onTap: onTap,
      radius: 50,
      gradient: false,
      color: isSelected ? context.adaptivePrimary : context.adaptiveBorder.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                plan.name,
                style: context.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : context.adaptiveDisabled,
                  fontSize: 17,
                ),
              ),
              
            ],
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Text(
                    '${plan.totalCreditsWithBonus} crédits',
                    style: context.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : context.adaptiveTextPrimary,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.formattedPrice,
                    style: context.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : context.adaptiveTextPrimary,
                      fontSize: 19,
                    ),
                  ),
                  Text(
                    '(${(plan.pricePerCredit).toStringAsFixed(2)}€/crédit)',
                    style: context.bodySmall?.copyWith(
                      color: isSelected ? Colors.white : context.adaptiveTextSecondary,
                      fontSize: 14,
                    ),
                  ),  
                ],
              ),
            ],
          ),      
        ],
      ),
    );
  }
}