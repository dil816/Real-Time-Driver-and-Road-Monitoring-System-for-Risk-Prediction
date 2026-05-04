import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/drive_profile.dart';
import '../../../provider/profile_provider/profile_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, prov, _) {
        final profile = prov.currentProfile;
        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          appBar: _buildAppBar(context, prov),
          body: profile == null
              ? _buildWaiting(prov)
              : _buildDashboard(context, prov, profile),
        );
      },
    );
  }

  // ──────────────────────────────────────────
  // AppBar
  // ──────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context, ProfileProvider prov) {
    return AppBar(
      backgroundColor: const Color(0xFF0D1220),
      elevation: 0,
      title: Row(
        children: [
          const Icon(
            Icons.directions_car_rounded,
            color: Color(0xFF6C63FF),
            size: 26,
          ),
          const SizedBox(width: 10),
          const Text(
            'Driver Behaviour',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        // Connection indicator
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: prov.connected
                        ? const Color(0xFF00E676)
                        : Colors.redAccent,
                    boxShadow: prov.connected
                        ? [
                      BoxShadow(
                        color: const Color(
                          0xFF00E676,
                        ).withAlpha((255 * 0.6).round()), // Changed here
                        blurRadius: 8,
                      ),
                    ]
                        : [],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  prov.connected ? 'Live' : 'Offline',
                  style: TextStyle(
                    color: prov.connected
                        ? const Color(0xFF00E676)
                        : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Device selector
        if (prov.deviceIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: const Color(0xFF1A2035),
                value: prov.selectedDevice,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                icon: const Icon(
                  Icons.expand_more,
                  color: Colors.white54,
                  size: 18,
                ),
                items: prov.deviceIds
                    .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                    .toList(),
                onChanged: (id) => id != null ? prov.selectDevice(id) : null,
              ),
            ),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ──────────────────────────────────────────
  // Waiting state
  // ──────────────────────────────────────────
  Widget _buildWaiting(ProfileProvider prov) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            prov.connected
                ? 'Waiting for first data…'
                : 'Connecting to server…',
            style: const TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'ws://${prov.host}/ws',
            style: const TextStyle(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  // Main dashboard
  // ──────────────────────────────────────────
  Widget _buildDashboard(
      BuildContext context,
      ProfileProvider prov,
      DriverProfile p,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row: rank badge + prediction chip
          Row(
            children: [
              Expanded(child: _RankCard(profile: p)),
              const SizedBox(width: 12),
              _PredictionChip(prediction: p.prediction),
            ],
          ),
          const SizedBox(height: 14),

          // Score bars
          _ScoreCard(
            label: 'Short-term Score (Trip)',
            icon: Icons.timeline,
            value: p.stMean,
            color: _scoreColor(p.stMean),
          ),
          const SizedBox(height: 10),
          _ScoreCard(
            label: 'Long-term Score (Lifetime)',
            icon: Icons.history,
            value: p.ltMean,
            color: _scoreColor(p.ltMean),
          ),
          const SizedBox(height: 18),

          // Alert log
          _AlertLog(alerts: prov.alertLog),
        ],
      ),
    );
  }

  Color _scoreColor(double? v) {
    if (v == null) return Colors.white38;
    if (v >= 85) return const Color(0xFF00E676);
    if (v >= 60) return const Color(0xFFFFD740);
    return const Color(0xFFFF5252);
  }
}

// ──────────────────────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────────────────────

class _RankCard extends StatelessWidget {
  final DriverProfile profile;
  const _RankCard({required this.profile});

  Color get _rankColor {
    final r = profile.rank ?? '';
    if (r.startsWith('Rank S')) return const Color(0xFFFFD700);
    if (r.startsWith('Rank A')) return const Color(0xFF00E676);
    if (r.startsWith('Rank B')) return const Color(0xFF64B5F6);
    if (r.startsWith('Rank C')) return const Color(0xFFFFD740);
    if (r.startsWith('Rank D')) return const Color(0xFFFF9800);
    return const Color(0xFFFF5252); // F
  }

  @override
  Widget build(BuildContext context) {
    final rank = profile.rank ?? '—';
    // Shorten "Rank S (Elite)" → "S"
    final letter = rank.length > 7 ? rank.substring(5, 6) : rank;
    final subtitle = rank.contains('(')
        ? rank.substring(rank.indexOf('(') + 1, rank.indexOf(')'))
        : rank;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _rankColor.withAlpha((255 * 0.15).round()), // Changed here
            const Color(0xFF0D1220),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _rankColor.withAlpha((255 * 0.4).round()), // Changed here
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _rankColor.withAlpha((255 * 0.2).round()), // Changed here
              shape: BoxShape.circle,
              border: Border.all(color: _rankColor, width: 2),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  color: _rankColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Rank',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: _rankColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                profile.deviceId,
                style: const TextStyle(color: Colors.white30, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PredictionChip extends StatelessWidget {
  final String prediction;
  const _PredictionChip({required this.prediction});

  Color get _color {
    switch (prediction) {
      case 'SAFE':
        return const Color(0xFF00E676);
      case 'FAST':
        return const Color(0xFFFFD740);
      case 'UNSTABLE':
        return const Color(0xFFFF5252);
      case 'INSTANT':
        return const Color(0xFFFF1744);
      default:
        return Colors.white24;
    }
  }

  IconData get _icon {
    switch (prediction) {
      case 'SAFE':
        return Icons.check_circle_outline;
      case 'FAST':
        return Icons.speed;
      case 'UNSTABLE':
        return Icons.warning_amber_rounded;
      case 'INSTANT':
        return Icons.flash_on;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: _color.withAlpha((255 * 0.12).round()), // Changed here
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _color.withAlpha((255 * 0.5).round()), // Changed here
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(_icon, color: _color, size: 28),
          const SizedBox(height: 6),
          Text(
            prediction,
            style: TextStyle(
              color: _color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final double? value;
  final Color color;

  const _ScoreCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const Spacer(),
              Text(
                value == null ? '—' : v.toStringAsFixed(1),
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                height: 8,
                width:
                (value == null ? 0 : v / 100) *
                    MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withAlpha((255 * 0.6).round()), // Changed here
                      color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertLog extends StatelessWidget {
  final List<String> alerts;
  const _AlertLog({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFF6C63FF),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Alert Log',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  '${alerts.length} events',
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No alerts yet — driving looks good! 👍',
                  style: TextStyle(color: Colors.white30, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length > 20 ? 20 : alerts.length,
              separatorBuilder: (_, __) =>
              const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, i) {
                final a = alerts[i];
                final isWarning =
                    a.contains('🚨') ||
                        a.contains('⚠️') ||
                        a.contains('INSTANT');
                final isRank = a.contains('🏆') || a.contains('RANK');
                final isDrift = a.contains('⚡') || a.contains('PATTERN');

                Color alertColor = Colors.white54;
                if (isWarning) alertColor = const Color(0xFFFF5252);
                if (isRank) alertColor = const Color(0xFFFFD740);
                if (isDrift) alertColor = const Color(0xFF6C63FF);

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    a,
                    style: TextStyle(
                      color: alertColor,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
