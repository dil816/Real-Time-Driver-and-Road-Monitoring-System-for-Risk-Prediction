import 'package:flutter/material.dart';

import '../models/fatigue_data.dart';
import '../theme.dart';
import 'dashboard_card.dart';

class ComponentScoreCard extends StatelessWidget {
  final String label;
  final ComponentScore score;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final String subtitleText;

  const ComponentScoreCard({
    super.key,
    required this.label,
    required this.score,
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.subtitleText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${(score.score * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ScoreProgressBar(value: score.score, colors: gradientColors),
          const SizedBox(height: 8),
          Text(
            subtitleText,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class AdaptiveWeightBar extends StatelessWidget {
  final String label;
  final double value;
  final Color textColor;
  final List<Color> gradientColors;

  const AdaptiveWeightBar({
    super.key,
    required this.label,
    required this.value,
    required this.textColor,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(value * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ScoreProgressBar(value: value, colors: gradientColors, height: 14),
      ],
    );
  }
}
