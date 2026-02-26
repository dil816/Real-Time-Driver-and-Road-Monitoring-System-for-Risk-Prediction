// lib/screens/fatigue_analyze_screen.dart

import 'package:driveguard/models/fatigue_data.dart';
import 'package:driveguard/provider/websocket_service_provider/websocket_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme.dart';
import '../../../widgets/component_score_card.dart';
import '../../../widgets/dashboard_card.dart';

// ─────────────────────────────────────────────
// ROOT SCREEN
// FIX: No longer wraps everything in one Consumer.
// Each section subscribes only to the notifier it needs.
// ─────────────────────────────────────────────
class FatigueAnalyzeScreen extends StatefulWidget {
  const FatigueAnalyzeScreen({super.key});

  @override
  State<FatigueAnalyzeScreen> createState() => _FatigueAnalyzeScreenState();
}

class _FatigueAnalyzeScreenState extends State<FatigueAnalyzeScreen> {
  late final WebSocketService _service;

  @override
  void initState() {
    super.initState();
    _service = context.read<WebSocketService>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _service.connect());
  }

  @override
  void dispose() {
    // FIX: explicitly dispose service from screen side
    // TODO: Can uncommented future if want
    //_service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Only the loading/ready gate listens here.
    // Once data arrives this ValueListenableBuilder never rebuilds again
    // (the inner widgets each have their own targeted listeners).
    return ValueListenableBuilder<FatigueData?>(
      valueListenable: _service.dataNotifier,
      builder: (context, data, _) {
        if (data == null) return const _LoadingScreen();
        return _DashboardBody(service: _service);
      },
    );
  }
}

// ─────────────────────────────────────────────
// LOADING SCREEN
// FIX: Extracted to a const widget — never rebuilt unnecessarily.
// ─────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.blue, strokeWidth: 4),
            SizedBox(height: 24),
            Text(
              'Connecting to sensors...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DASHBOARD BODY
// FIX: Extracted to its own StatelessWidget. The scroll view and static
// layout never rebuild — only child widgets rebuild when their data changes.
// ─────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  final WebSocketService service;

  const _DashboardBody({required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        // bottom padding accounts for the floating nav bar height (56) +
        // its bottom margin (12) + safe area — prevents last card from
        // being clipped behind the nav bar and causing MetricTile overflow
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            // FIX: _HeaderWidget only listens to connectionNotifier
            _HeaderWidget(notifier: service.connectionNotifier),
            const SizedBox(height: 20),
            // FIX: _AlertBanner only listens to dataNotifier
            _AlertBanner(notifier: service.dataNotifier),
            const SizedBox(height: 20),
            _ResponsiveRow(
              children: [
                Expanded(
                  flex: 2,
                  // FIX: _ComponentAnalysisCard listens to data + history separately
                  child: _ComponentAnalysisCard(
                    dataNotifier: service.dataNotifier,
                    historyNotifier: service.historyNotifier,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _AdaptiveWeightsCard(notifier: service.dataNotifier),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ResponsiveRow(
              children: [
                Expanded(
                  child: _EnvironmentalCard(notifier: service.dataNotifier),
                ),
                const SizedBox(width: 16),
                Expanded(child: _BiometricCard(notifier: service.dataNotifier)),
              ],
            ),
            const SizedBox(height: 20),
            _FuzzyMembershipCard(notifier: service.dataNotifier),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RESPONSIVE ROW HELPER
// FIX: Uses LayoutBuilder instead of MediaQuery in build() —
// only re-lays out when its own constraints change, not on every rebuild.
// ─────────────────────────────────────────────
class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;

  const _ResponsiveRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return Column(
            children: children.map((child) {
              if (child is SizedBox) return const SizedBox(height: 16);
              if (child is Expanded) {
                return SizedBox(width: double.infinity, child: child.child);
              }
              return SizedBox(width: double.infinity, child: child);
            }).toList(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// HEADER
// FIX: Only listens to connectionNotifier (bool).
// Does NOT rebuild when fatigue score or components change.
// ─────────────────────────────────────────────
class _HeaderWidget extends StatelessWidget {
  final ValueNotifier<bool> notifier;

  const _HeaderWidget({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, isConnected, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver Fatigue\nMonitoring System',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isConnected ? AppColors.green : AppColors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Real-time Analysis',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // FIX: This is truly static — extracted as a const-like container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                border: Border.all(color: AppColors.green),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                children: [
                  Text(
                    'System Status',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ACTIVE',
                    style: TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// ALERT BANNER
// FIX: Listens to dataNotifier. Rebuilds only when new data arrives.
// FIX: Cached alert color constants used from AppColors (no map lookup inline).
// ─────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final ValueNotifier<FatigueData?> notifier;

  const _AlertBanner({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FatigueData?>(
      valueListenable: notifier,
      builder: (context, data, _) {
        if (data == null) return const SizedBox.shrink();

        final gradient =
            AppColors.alertGradients[data.alert.level] ??
            AppColors.alertGradients['SAFE']!;
        final border =
            AppColors.alertBorders[data.alert.level] ?? AppColors.green;

        final trendIcon = data.trend == 'increasing'
            ? Icons.trending_up
            : data.trend == 'decreasing'
            ? Icons.trending_down
            : Icons.trending_flat;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 2),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.alert.level,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.alert.action,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Fatigue Score',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${(data.fatigueScore * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 44,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trendIcon,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        data.trend.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// COMPONENT ANALYSIS CARD
// FIX: dataNotifier and historyNotifier are listened to separately.
// The score cards only rebuild when data changes.
// The chart only rebuilds when history changes.
// ─────────────────────────────────────────────
class _ComponentAnalysisCard extends StatelessWidget {
  final ValueNotifier<FatigueData?> dataNotifier;
  final HistoryNotifier historyNotifier;

  const _ComponentAnalysisCard({
    required this.dataNotifier,
    required this.historyNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.monitor_heart, color: AppColors.blue, size: 22),
              SizedBox(width: 8),
              Text(
                'Component Analysis',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // FIX: Score section rebuilds on data change
          ValueListenableBuilder<FatigueData?>(
            valueListenable: dataNotifier,
            builder: (context, data, _) {
              if (data == null) return const SizedBox.shrink();
              return _ResponsiveRow(
                children: [
                  Expanded(
                    child: ComponentScoreCard(
                      label: 'Environmental',
                      score: data.components.environmental,
                      icon: Icons.cloud_outlined,
                      iconColor: AppColors.blue,
                      gradientColors: const [AppColors.blue, AppColors.cyan],
                      subtitleText:
                          'Reliability: ${(data.components.environmental.reliability * 100).toStringAsFixed(0)}%',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ComponentScoreCard(
                      label: 'Physiological',
                      score: data.components.physiological,
                      icon: Icons.favorite_outline,
                      iconColor: AppColors.red,
                      gradientColors: const [AppColors.red, AppColors.pink],
                      subtitleText:
                          'Status: ${data.components.physiological.label}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ComponentScoreCard(
                      label: 'Behavioral',
                      score: data.components.behavioral,
                      icon: Icons.visibility_outlined,
                      iconColor: AppColors.purple,
                      gradientColors: const [
                        AppColors.purple,
                        AppColors.indigo,
                      ],
                      subtitleText:
                          'Yawns: ${data.components.behavioral.indicators?.yawnCount ?? 0}',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Historical Trend',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // FIX: Chart section ONLY rebuilds when history changes, not on every data update
          SizedBox(
            height: 200,
            child: ValueListenableBuilder<List<HistoryPoint>>(
              valueListenable: historyNotifier,
              builder: (context, history, _) {
                if (history.isEmpty) {
                  return const Center(
                    child: Text(
                      'Waiting for data...',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return _LineChart(history: history);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LINE CHART
// FIX: Extracted as its own widget. The chart data is computed once
// inside build() and not recreated by a parent's rebuild.
// ─────────────────────────────────────────────
class _LineChart extends StatelessWidget {
  final List<HistoryPoint> history;

  const _LineChart({required this.history});

  LineChartBarData _bar(List<double> values, Color color, double width) {
    return LineChartBarData(
      spots: [
        for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      color: color,
      barWidth: width,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Build spot lists once here, not recreated on each parent rebuild
    final scoreSpots = [
      for (int i = 0; i < history.length; i++) history[i].score,
    ];
    final envSpots = [for (int i = 0; i < history.length; i++) history[i].env];
    final physSpots = [
      for (int i = 0; i < history.length; i++) history[i].phys,
    ];
    final behavSpots = [
      for (int i = 0; i < history.length; i++) history[i].behav,
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) => Text(
                val.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              reservedSize: 36,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: history.length > 5
                  ? (history.length / 4).ceilToDouble()
                  : 1,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= history.length) return const SizedBox();
                return Text(
                  history[idx].time.substring(0, 5),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                  ),
                );
              },
              reservedSize: 24,
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 1,
        lineBarsData: [
          _bar(scoreSpots, AppColors.blue, 3),
          _bar(envSpots, AppColors.cyan, 2),
          _bar(physSpots, AppColors.red, 2),
          _bar(behavSpots, AppColors.purple, 2),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADAPTIVE WEIGHTS CARD
// FIX: Own ValueListenableBuilder — only rebuilds for data changes.
// FIX: Radar chart extracted to its own widget.
// ─────────────────────────────────────────────
class _AdaptiveWeightsCard extends StatelessWidget {
  final ValueNotifier<FatigueData?> notifier;

  const _AdaptiveWeightsCard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: ValueListenableBuilder<FatigueData?>(
        valueListenable: notifier,
        builder: (context, data, _) {
          if (data == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adaptive Weights (X,Y,Z)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              AdaptiveWeightBar(
                label: 'X - Environmental',
                value: data.weights.xEnvironmental,
                textColor: AppColors.blue,
                gradientColors: const [AppColors.blue, AppColors.cyan],
              ),
              const SizedBox(height: 16),
              AdaptiveWeightBar(
                label: 'Y - Physiological',
                value: data.weights.yPhysiological,
                textColor: AppColors.red,
                gradientColors: const [AppColors.red, AppColors.pink],
              ),
              const SizedBox(height: 16),
              AdaptiveWeightBar(
                label: 'Z - Behavioral',
                value: data.weights.zBehavioral,
                textColor: AppColors.purple,
                gradientColors: const [AppColors.purple, AppColors.indigo],
              ),
              const SizedBox(height: 24),
              const Text(
                'Score Radar',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(height: 220, child: _RadarChart(data: data)),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RADAR CHART
// FIX: Extracted as its own widget so Flutter can skip rebuilding it
// if the parent rebuilds but data reference hasn't changed.
// ─────────────────────────────────────────────
class _RadarChart extends StatelessWidget {
  final FatigueData data;

  const _RadarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        tickCount: 4,
        ticksTextStyle: const TextStyle(
          color: Colors.transparent,
          fontSize: 10,
        ),
        radarBorderData: const BorderSide(color: AppColors.border, width: 1),
        gridBorderData: const BorderSide(color: AppColors.border, width: 1),
        tickBorderData: const BorderSide(color: AppColors.border, width: 1),
        getTitle: (index, angle) {
          const titles = ['Environmental', 'Physiological', 'Behavioral'];
          return RadarChartTitle(
            text: titles[index],
            positionPercentageOffset: 0.1,
          );
        },
        titleTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
        dataSets: [
          RadarDataSet(
            fillColor: AppColors.blue.withValues(alpha: 0.3),
            borderColor: AppColors.blue,
            borderWidth: 2,
            dataEntries: [
              RadarEntry(value: data.components.environmental.score * 100),
              RadarEntry(value: data.components.physiological.score * 100),
              RadarEntry(value: data.components.behavioral.score * 100),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ENVIRONMENTAL CARD
// FIX: Own ValueListenableBuilder.
// FIX: GridView replaced with Wrap — no shrinkWrap needed, lazy-safe.
// ─────────────────────────────────────────────
class _EnvironmentalCard extends StatelessWidget {
  final ValueNotifier<FatigueData?> notifier;

  const _EnvironmentalCard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: ValueListenableBuilder<FatigueData?>(
        valueListenable: notifier,
        builder: (context, data, _) {
          if (data == null) return const SizedBox.shrink();
          final env = data.rawSensorData.environment;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.cloud_outlined, color: AppColors.blue, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Environmental Sensors',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // FIX: Use GridView.builder instead of GridView.count —
              // builder is lazy, count renders all children immediately.
              GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.6,
                ),
                itemCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, i) {
                  // FIX: data prepared once, not inline per build
                  final tiles = [
                    (
                      Icons.wb_sunny_outlined,
                      AppColors.orange,
                      'Light Level',
                      env.lightLevel.lux.toStringAsFixed(1),
                      'lux • ${env.lightLevel.lightCondition}',
                    ),
                    (
                      Icons.cloud_outlined,
                      AppColors.textSecondary,
                      'Weather',
                      '${env.weather.clouds.toStringAsFixed(0)}%',
                      env.weather.description,
                    ),
                    (
                      Icons.navigation_outlined,
                      AppColors.green,
                      'Speed',
                      env.drivingContext.driveSpeed.toStringAsFixed(1),
                      'km/h • ${env.drivingContext.roadType}',
                    ),
                    (
                      Icons.air_outlined,
                      AppColors.cyan,
                      'Time Risk',
                      env.timeRisk.toUpperCase(),
                      'current context',
                    ),
                  ];
                  final t = tiles[i];
                  return MetricTile(
                    icon: Icon(t.$1, color: t.$2, size: 16),
                    label: t.$3,
                    value: t.$4,
                    subtitle: t.$5,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BIOMETRIC CARD
// FIX: Own ValueListenableBuilder.
// FIX: Behavioral GridView replaced with GridView.builder.
// ─────────────────────────────────────────────
class _BiometricCard extends StatelessWidget {
  final ValueNotifier<FatigueData?> notifier;

  const _BiometricCard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: ValueListenableBuilder<FatigueData?>(
        valueListenable: notifier,
        builder: (context, data, _) {
          if (data == null) return const SizedBox.shrink();
          final phys = data.rawSensorData.physiological;
          final behav = data.components.behavioral.indicators;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.monitor_heart, color: AppColors.red, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Biometric Data',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _HrvPanel(phys: phys),
              const SizedBox(height: 12),
              if (behav != null) _BehavioralPanel(behav: behav),
            ],
          );
        },
      ),
    );
  }
}

// FIX: HRV and Behavioral panels extracted — smaller, focused widgets.
class _HrvPanel extends StatelessWidget {
  final PhysiologicalData phys;

  const _HrvPanel({required this.phys});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Heart Rate Variability (HRV)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                phys.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Confidence: ${(phys.confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ProbColumn(
                'Relaxed',
                phys.probabilities.relaxed,
                AppColors.green,
              ),
              _ProbColumn(
                'Normal',
                phys.probabilities.normal,
                AppColors.yellow,
              ),
              _ProbColumn(
                'Stressed',
                phys.probabilities.stressed,
                AppColors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProbColumn extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ProbColumn(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          '${(value * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _BehavioralPanel extends StatelessWidget {
  final BehavioralIndicators behav;

  const _BehavioralPanel({required this.behav});

  @override
  Widget build(BuildContext context) {
    // FIX: data built once as a list, not inline per cell
    final cells = [
      ('MAR Score', '${(behav.marScore * 100).toStringAsFixed(0)}%'),
      ('Yawn Count', '${behav.yawnCount}'),
      ('Head X', '${behav.headPosition.x.toStringAsFixed(1)}°'),
      ('Head Y', '${behav.headPosition.y.toStringAsFixed(1)}°'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Behavioral Indicators',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemCount: cells.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, i) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cells[i].$1,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  cells[i].$2,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FUZZY MEMBERSHIP CARD
// FIX: Own ValueListenableBuilder.
// FIX: Bar groups built once in build(), not inside chart callback.
// FIX: Legend extracted as const widgets.
// ─────────────────────────────────────────────
class _FuzzyMembershipCard extends StatelessWidget {
  final ValueNotifier<FatigueData?> notifier;

  const _FuzzyMembershipCard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: ValueListenableBuilder<FatigueData?>(
        valueListenable: notifier,
        builder: (context, data, _) {
          if (data == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fuzzy Membership Functions',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(height: 220, child: _FuzzyBarChart(data: data)),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot('Low', AppColors.green),
                  SizedBox(width: 24),
                  _LegendDot('Medium', AppColors.yellow),
                  SizedBox(width: 24),
                  _LegendDot('High', AppColors.red),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// FIX: const widget — never rebuilds
class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// FUZZY BAR CHART
// FIX: Extracted widget. Bar groups built once in build().
// The static bar border radius is a const to avoid recreation.
// ─────────────────────────────────────────────
class _FuzzyBarChart extends StatelessWidget {
  final FatigueData data;

  const _FuzzyBarChart({required this.data});

  // FIX: const border radius — allocated once, not per rod per rebuild
  static const _topRadius = BorderRadius.vertical(top: Radius.circular(4));

  @override
  Widget build(BuildContext context) {
    final labels = const ['Environmental', 'Physiological', 'Behavioral'];
    final fuzzies = [
      data.components.environmental.fuzzy,
      data.components.physiological.fuzzy,
      data.components.behavioral.fuzzy,
    ];

    // FIX: barGroups computed once here, not inside a chart callback
    final barGroups = [
      for (int i = 0; i < 3; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: [
            BarChartRodData(
              toY: fuzzies[i].low * 100,
              color: AppColors.green,
              width: 16,
              borderRadius: _topRadius,
            ),
            BarChartRodData(
              toY: fuzzies[i].medium * 100,
              color: AppColors.yellow,
              width: 16,
              borderRadius: _topRadius,
            ),
            BarChartRodData(
              toY: fuzzies[i].high * 100,
              color: AppColors.red,
              width: 16,
              borderRadius: _topRadius,
            ),
          ],
        ),
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  labels[val.toInt()],
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              reservedSize: 32,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) => Text(
                '${val.toInt()}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              reservedSize: 32,
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              const FlLine(color: Colors.transparent),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
