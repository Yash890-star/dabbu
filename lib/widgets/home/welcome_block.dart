import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_spacing.dart';
import '../app_card.dart';

class WelcomeBlock extends StatelessWidget {
  final String userName;
  final VoidCallback? onNotificationTap;
  final int notificationCount;

  const WelcomeBlock({
    super.key,
    this.userName = "User",
    this.onNotificationTap,
    this.onScanSms, // New callback
    this.notificationCount = 0,
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
        horizontal:
            AppSpacing
                .lg, // 20 -> ~24 (AppSpacing.lg) or create custom? Let's use 24 or 16
        // User had 20. AppSpacing.md=16, AppSpacing.lg=24. Let's stick to 'md' for vertical=16.
        // For horizontal 20, it's close to 16 or 24. Let's unify on 16 (md) for consistency or 24(lg).
        // Let's use `AppSpacing.md` (16) to be consistent with Card defaults, unless 20 is special.
        // Actually, let's keep it clean: symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md)
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
              // Scan SMS Button (Moved here)
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
              const SizedBox(width: 8),

              // Notification Button
              Stack(
                children: [
                  IconButton(
                    onPressed: onNotificationTap,
                    icon: const Icon(Icons.notifications_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.expense,
                          shape: BoxShape.circle,
                        ),
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
