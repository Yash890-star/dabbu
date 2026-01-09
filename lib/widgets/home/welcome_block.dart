import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../app_card.dart';

class WelcomeBlock extends StatelessWidget {
  final String userName;

  final bool isPrivacyEnabled;
  final VoidCallback? onPrivacyToggle;
  final VoidCallback? onAddPattern; // New Callback

  const WelcomeBlock({
    super.key,
    this.userName = "User",
    this.onScanSms,
    this.isPrivacyEnabled = false,
    this.onPrivacyToggle,
    this.onAddPattern,
  });

  final VoidCallback? onScanSms;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _greeting,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Privacy Toggle
              IconButton(
                onPressed: onPrivacyToggle,
                icon: Icon(
                  isPrivacyEnabled
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                tooltip: "Toggle Privacy",
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 4),

              // Scan SMS Button
              IconButton(
                onPressed: onScanSms,
                icon: const Icon(Icons.document_scanner_outlined, size: 20),
                tooltip: "Scan SMS",
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (onAddPattern != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onAddPattern,
                  icon: const Icon(Icons.auto_fix_high, size: 20),
                  tooltip: "Add SMS Pattern",
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                    foregroundColor: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
