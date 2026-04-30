/// Data model for a driver profile message from the server.
class DriverProfile {
  final String deviceId;
  final double? stMean;
  final double? ltMean;
  final String? rank;
  final List<String> alerts;
  final String prediction;

  const DriverProfile({
    required this.deviceId,
    this.stMean,
    this.ltMean,
    this.rank,
    this.alerts = const [],
    this.prediction = 'NONE',
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      deviceId: json['device_id'] as String? ?? 'unknown',
      stMean: (json['st_mean'] as num?)?.toDouble(),
      ltMean: (json['lt_mean'] as num?)?.toDouble(),
      rank: json['rank'] as String?,
      alerts: List<String>.from(json['alerts'] as List? ?? []),
      prediction: json['prediction'] as String? ?? 'NONE',
    );
  }

  DriverProfile copyWith({
    double? stMean,
    double? ltMean,
    String? rank,
    List<String>? alerts,
    String? prediction,
  }) {
    return DriverProfile(
      deviceId: deviceId,
      stMean: stMean ?? this.stMean,
      ltMean: ltMean ?? this.ltMean,
      rank: rank ?? this.rank,
      alerts: alerts ?? this.alerts,
      prediction: prediction ?? this.prediction,
    );
  }
}
