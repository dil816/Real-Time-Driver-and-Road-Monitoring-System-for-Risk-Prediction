class DriverProfile {
  final String deviceId;
  final double stMean;
  final double ltMean;
  final String rank;
  final List<String> alerts;

  DriverProfile({
    required this.deviceId,
    required this.stMean,
    required this.ltMean,
    required this.rank,
    required this.alerts,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      deviceId: json['device_id'] ?? 'UNKNOWN',
      stMean: (json['st_mean'] ?? 100.0).toDouble(),
      ltMean: (json['lt_mean'] ?? 100.0).toDouble(),
      rank: json['rank'] ?? 'S',
      alerts: List<String>.from(json['alerts'] ?? []),
    );
  }
}