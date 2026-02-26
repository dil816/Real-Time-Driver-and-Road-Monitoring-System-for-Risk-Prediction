class FatigueData {
  final double fatigueScore;
  final String trend;
  final String timestamp;
  final AlertInfo alert;
  final Components components;
  final Weights weights;
  final RawSensorData rawSensorData;

  FatigueData({
    required this.fatigueScore,
    required this.trend,
    required this.timestamp,
    required this.alert,
    required this.components,
    required this.weights,
    required this.rawSensorData,
  });

  factory FatigueData.fromJson(Map<String, dynamic> json) {
    return FatigueData(
      fatigueScore: (json['fatigue_score'] as num).toDouble(),
      trend: json['trend'] as String,
      timestamp: json['timestamp'] as String,
      alert: AlertInfo.fromJson(json['alert'] as Map<String, dynamic>),
      components: Components.fromJson(
        json['components'] as Map<String, dynamic>,
      ),
      weights: Weights.fromJson(json['weights'] as Map<String, dynamic>),
      rawSensorData: RawSensorData.fromJson(
        json['raw_sensor_data'] as Map<String, dynamic>,
      ),
    );
  }
}

class AlertInfo {
  final String level;
  final String action;

  AlertInfo({required this.level, required this.action});

  factory AlertInfo.fromJson(Map<String, dynamic> json) {
    return AlertInfo(
      level: json['level'] as String,
      action: json['action'] as String,
    );
  }
}

class Components {
  final ComponentScore environmental;
  final ComponentScore physiological;
  final ComponentScore behavioral;

  Components({
    required this.environmental,
    required this.physiological,
    required this.behavioral,
  });

  factory Components.fromJson(Map<String, dynamic> json) {
    return Components(
      environmental: ComponentScore.fromJson(
        json['environmental'] as Map<String, dynamic>,
      ),
      physiological: ComponentScore.fromJson(
        json['physiological'] as Map<String, dynamic>,
      ),
      behavioral: ComponentScore.fromJson(
        json['behavioral'] as Map<String, dynamic>,
        isBehavioral: true,
      ),
    );
  }
}

class ComponentScore {
  final double score;
  final double reliability;
  final String label;
  final FuzzyScore fuzzy;
  final BehavioralIndicators? indicators;

  ComponentScore({
    required this.score,
    required this.reliability,
    required this.label,
    required this.fuzzy,
    this.indicators,
  });

  factory ComponentScore.fromJson(
    Map<String, dynamic> json, {
    bool isBehavioral = false,
  }) {
    return ComponentScore(
      score: (json['score'] as num).toDouble(),
      reliability: json.containsKey('reliability')
          ? (json['reliability'] as num).toDouble()
          : 1.0,
      label: json['label'] as String? ?? '',
      fuzzy: FuzzyScore.fromJson(json['fuzzy'] as Map<String, dynamic>),
      indicators: isBehavioral && json.containsKey('indicators')
          ? BehavioralIndicators.fromJson(
              json['indicators'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class FuzzyScore {
  final double low;
  final double medium;
  final double high;

  FuzzyScore({required this.low, required this.medium, required this.high});

  factory FuzzyScore.fromJson(Map<String, dynamic> json) {
    return FuzzyScore(
      low: (json['low'] as num).toDouble(),
      medium: (json['medium'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
    );
  }
}

class BehavioralIndicators {
  final double marScore;
  final int yawnCount;
  final HeadPosition headPosition;

  BehavioralIndicators({
    required this.marScore,
    required this.yawnCount,
    required this.headPosition,
  });

  factory BehavioralIndicators.fromJson(Map<String, dynamic> json) {
    return BehavioralIndicators(
      marScore: (json['mar_score'] as num).toDouble(),
      yawnCount: json['yawn_count'] as int,
      headPosition: HeadPosition.fromJson(
        json['head_position'] as Map<String, dynamic>,
      ),
    );
  }
}

class HeadPosition {
  final double x;
  final double y;

  HeadPosition({required this.x, required this.y});

  factory HeadPosition.fromJson(Map<String, dynamic> json) {
    return HeadPosition(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}

class Weights {
  final double xEnvironmental;
  final double yPhysiological;
  final double zBehavioral;

  Weights({
    required this.xEnvironmental,
    required this.yPhysiological,
    required this.zBehavioral,
  });

  factory Weights.fromJson(Map<String, dynamic> json) {
    return Weights(
      xEnvironmental: (json['X_environmental'] as num).toDouble(),
      yPhysiological: (json['Y_physiological'] as num).toDouble(),
      zBehavioral: (json['Z_behavioral'] as num).toDouble(),
    );
  }
}

class RawSensorData {
  final EnvironmentData environment;
  final PhysiologicalData physiological;

  RawSensorData({required this.environment, required this.physiological});

  factory RawSensorData.fromJson(Map<String, dynamic> json) {
    return RawSensorData(
      environment: EnvironmentData.fromJson(
        json['environment'] as Map<String, dynamic>,
      ),
      physiological: PhysiologicalData.fromJson(
        json['physiological'] as Map<String, dynamic>,
      ),
    );
  }
}

class EnvironmentData {
  final LightLevel lightLevel;
  final WeatherData weather;
  final DrivingContext drivingContext;
  final String timeRisk;

  EnvironmentData({
    required this.lightLevel,
    required this.weather,
    required this.drivingContext,
    required this.timeRisk,
  });

  factory EnvironmentData.fromJson(Map<String, dynamic> json) {
    return EnvironmentData(
      lightLevel: LightLevel.fromJson(
        json['light_level'] as Map<String, dynamic>,
      ),
      weather: WeatherData.fromJson(json['weather'] as Map<String, dynamic>),
      drivingContext: DrivingContext.fromJson(
        json['driving_context'] as Map<String, dynamic>,
      ),
      timeRisk: json['time_risk'] as String,
    );
  }
}

class LightLevel {
  final double lux;
  final String lightCondition;

  LightLevel({required this.lux, required this.lightCondition});

  factory LightLevel.fromJson(Map<String, dynamic> json) {
    return LightLevel(
      lux: (json['lux'] as num).toDouble(),
      lightCondition: json['light_condition'] as String,
    );
  }
}

class WeatherData {
  final double clouds;
  final String description;

  WeatherData({required this.clouds, required this.description});

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      clouds: (json['clouds'] as num).toDouble(),
      description: json['description'] as String,
    );
  }
}

class DrivingContext {
  final double driveSpeed;
  final String roadType;

  DrivingContext({required this.driveSpeed, required this.roadType});

  factory DrivingContext.fromJson(Map<String, dynamic> json) {
    return DrivingContext(
      driveSpeed: (json['drive_speed'] as num).toDouble(),
      roadType: json['road_type'] as String,
    );
  }
}

class PhysiologicalData {
  final String label;
  final double confidence;
  final HrvProbabilities probabilities;

  PhysiologicalData({
    required this.label,
    required this.confidence,
    required this.probabilities,
  });

  factory PhysiologicalData.fromJson(Map<String, dynamic> json) {
    return PhysiologicalData(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      probabilities: HrvProbabilities.fromJson(
        json['probabilities'] as Map<String, dynamic>,
      ),
    );
  }
}

class HrvProbabilities {
  final double relaxed;
  final double normal;
  final double stressed;

  HrvProbabilities({
    required this.relaxed,
    required this.normal,
    required this.stressed,
  });

  factory HrvProbabilities.fromJson(Map<String, dynamic> json) {
    return HrvProbabilities(
      relaxed: (json['relaxed'] as num).toDouble(),
      normal: (json['normal'] as num).toDouble(),
      stressed: (json['stressed'] as num).toDouble(),
    );
  }
}

class HistoryPoint {
  final String time;
  final double score;
  final double env;
  final double phys;
  final double behav;

  HistoryPoint({
    required this.time,
    required this.score,
    required this.env,
    required this.phys,
    required this.behav,
  });
}
