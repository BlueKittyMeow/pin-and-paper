import 'package:flutter/material.dart' hide Badge;

import '../../models/badge.dart';
import '../../utils/theme.dart';

/// Displays a single badge with its image, name, and description.
///
/// Used on the badge reveal screen after quiz completion.
/// Animates in with a scale + fade transition when [animate] is true.
class BadgeCard extends StatefulWidget {
  final Badge badge;
  final Duration delay;
  final bool animate;

  const BadgeCard({
    super.key,
    required this.badge,
    this.delay = Duration.zero,
    this.animate = true,
  });

  @override
  State<BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<BadgeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    if (widget.animate) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.creamPaper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.badge.isCombo
                  ? AppTheme.mutedLavender.withValues(alpha: 0.6)
                  : AppTheme.kraftPaper,
              width: widget.badge.isCombo ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.deepShadow.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge image
              SizedBox(
                width: 72,
                height: 72,
                child: Image.asset(
                  widget.badge.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback icon when image asset is missing
                    return Container(
                      decoration: BoxDecoration(
                        color: _categoryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _categoryIcon,
                        size: 36,
                        color: _categoryColor,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Badge name
              Text(
                widget.badge.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.richBlack,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Badge description
              Text(
                widget.badge.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.muted,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Combo indicator
              if (widget.badge.isCombo) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.mutedLavender.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'COMBO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedLavender,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color get _categoryColor {
    switch (widget.badge.category) {
      case BadgeCategory.circadianRhythm:
        return AppTheme.info;
      case BadgeCategory.weekStructure:
        return AppTheme.softSage;
      case BadgeCategory.dailyRhythm:
        return AppTheme.warning;
      case BadgeCategory.displayPreference:
        return AppTheme.mutedLavender;
      case BadgeCategory.taskManagement:
        return AppTheme.success;
      case BadgeCategory.combo:
        return AppTheme.mutedLavender;
    }
  }

  IconData get _categoryIcon {
    switch (widget.badge.category) {
      case BadgeCategory.circadianRhythm:
        return Icons.nightlight_round;
      case BadgeCategory.weekStructure:
        return Icons.calendar_today;
      case BadgeCategory.dailyRhythm:
        return Icons.wb_sunny;
      case BadgeCategory.displayPreference:
        return Icons.schedule;
      case BadgeCategory.taskManagement:
        return Icons.task_alt;
      case BadgeCategory.combo:
        return Icons.stars;
    }
  }
}
