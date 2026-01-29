import 'package:flutter/material.dart' hide Badge;

import '../models/badge.dart';
import '../utils/theme.dart';
import '../widgets/quiz/badge_card.dart';
import 'home_screen.dart';

/// Badge reveal ceremony shown after quiz completion.
///
/// Displays earned badges with staggered animations.
/// On continue, navigates to [HomeScreen] replacing the navigation stack.
class BadgeRevealScreen extends StatelessWidget {
  final List<Badge> badges;

  const BadgeRevealScreen({
    super.key,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final individualBadges = badges.where((b) => !b.isCombo).toList();
    final comboBadges = badges.where((b) => b.isCombo).toList();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.warmBeige,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Header
                const Text(
                  'Your Time Personality',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.richBlack,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  badges.isEmpty
                      ? 'Quiz complete! Your preferences have been saved.'
                      : 'You earned ${badges.length} badge${badges.length == 1 ? '' : 's'}!',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Badge grid (scrollable)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badges.isEmpty)
                          _buildEmptyState()
                        else ...[
                          // Individual badges
                          if (individualBadges.isNotEmpty) ...[
                            _buildBadgeGrid(individualBadges, startIndex: 0),
                          ],

                          // Combo badges section
                          if (comboBadges.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 12),
                              child: Text(
                                'Combo Badges',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.mutedLavender,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            _buildBadgeGrid(
                              comboBadges,
                              startIndex: individualBadges.length,
                            ),
                          ],
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Continue button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _navigateToHome(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.deepShadow,
                        foregroundColor: AppTheme.creamPaper,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue to App',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeGrid(List<Badge> badgeList, {required int startIndex}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns with spacing
        final crossAxisCount = constraints.maxWidth > 400 ? 3 : 2;
        final spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (crossAxisCount - 1))) /
                crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(badgeList.length, (index) {
            return SizedBox(
              width: itemWidth,
              height: itemWidth * (1 / 0.7),
              child: BadgeCard(
                badge: badgeList[index],
                delay: Duration(milliseconds: 200 + (startIndex + index) * 150),
                animate: true,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.settings_rounded,
              size: 64,
              color: AppTheme.muted.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your preferences have been configured!',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.muted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'You can adjust them anytime in Settings.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }
}
