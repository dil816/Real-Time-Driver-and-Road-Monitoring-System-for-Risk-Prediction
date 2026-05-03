import 'package:audioplayers/audioplayers.dart';

import 'app_notification_service.dart';

class AlertService {
  static final AlertService instance = AlertService._();

  AlertService._();

  final AudioPlayer _beepPlayer = AudioPlayer();
  DateTime? _lastAlertTime;
  static const _alertCooldown = Duration(seconds: 20);

  Future<void> evaluate(double fatigueScore) async {
    final score = fatigueScore * 100;
    final now = DateTime.now();

    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!) < _alertCooldown) {
      return;
    }
    if (score > 55) {
      _lastAlertTime = now;
      await AppNotificationService.instance.show(
        id: 1002,
        title: '🚨 CRITICAL Fatigue Level!',
        body:
            'Fatigue score: ${score.toStringAsFixed(1)}% — Stop driving immediately!',
      );
      await _playBeep(times: 3);
    } else if (score > 50) {
      _lastAlertTime = now;
      await AppNotificationService.instance.show(
        id: 1001,
        title: '⚠️ High Fatigue Detected!',
        body:
            'Fatigue score: ${score.toStringAsFixed(1)}% — Please pull over and rest.',
      );
      await _playBeep(times: 1);
    }
  }

  Future<void> _playBeep({int times = 1}) async {
    await _beepPlayer.stop();
    for (int i = 0; i < times; i++) {
      await _beepPlayer.play(AssetSource('sounds/beep.mp3'));
      await Future.delayed(const Duration(seconds: 3));
      await _beepPlayer.stop();
      if (i < times - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  void dispose() {
    _beepPlayer.dispose();
  }
}
