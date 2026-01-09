import 'package:flutter/material.dart';
import '../utils/cms.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import 'tally_screen.dart';
import 'goals_list_screen.dart';
import 'brain_screen.dart';
import '../viewmodels/home_view_model.dart'; // For passing to Tally/Goals if needed
// We'll init a HomeViewModel or pass one down? Ideally MainScreen provides it or we use Provider.
// For now, let's assume we can create/find one or pass it.
// However, GoalsListScreen accepts 'goals' list.
// Simpler approach: ToolsScreen can create its own ViewModel or reuse logic?
// Actually, TallyScreen needs ViewModel.
// Let's make ToolsScreen accept HomeViewModel reference if possible, or we pass callbacks.
// Wait, MainScreen builds pages. We can pass _homeKey.currentState?._viewModel
// Logic flow: Tools -> Tally (Needs VM).
// Let's stick to passing ViewModel or callbacks.
// But TallyScreen asks for ViewModel directly.

class ToolsScreen extends StatelessWidget {
  final HomeViewModel viewModel; // Shared state
  final VoidCallback onRefresh;

  const ToolsScreen({
    super.key,
    required this.viewModel,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          CMS.tools['title'] ?? 'Tools',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tally Card (Large)
            _ToolCard(
              title: CMS.tools['tally_title'] ?? 'Tally',
              subtitle: CMS.tools['tally_desc'] ?? 'Check Balance',
              icon: Icons.check_circle_outline,
              color: Colors.teal,
              isLarge: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TallyScreen(viewModel: viewModel),
                  ),
                ).then((_) => onRefresh());
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Goals Card
            _ToolCard(
              title: CMS.tools['goals_title'] ?? 'Goals',
              subtitle: CMS.tools['goals_desc'] ?? 'Manage Savings',
              icon: Icons.flag_outlined,
              color: AppColors.archiveIcon,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => GoalsListScreen(
                          goals: viewModel.goals,
                          onRefresh: viewModel.refreshData,
                        ),
                  ),
                ).then((_) => onRefresh());
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Brain Card
            _ToolCard(
              title: CMS.tools['brain_title'] ?? 'The Brain',
              subtitle: CMS.tools['brain_desc'] ?? 'Manage Rules',
              icon: Icons.psychology,
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BrainScreen()),
                ).then((_) => onRefresh());
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLarge;

  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(isLarge ? 24 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isLarge ? 16 : 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: isLarge ? 32 : 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isLarge ? 20 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isLarge ? 14 : 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Theme.of(context).disabledColor),
            ],
          ),
        ),
      ),
    );
  }
}
