import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 32 : 12,
          height: 8,
          decoration: BoxDecoration(
            color:
                isActive
                    ? AppColors.primary
                    : Colors.white24, // Brighter than disabledColor with alpha
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
