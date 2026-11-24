import 'notification_audio_player.dart';

NotificationAudioPlayer createNotificationAudioPlayer() =>
    _UnsupportedNotificationAudioPlayer();

class _UnsupportedNotificationAudioPlayer implements NotificationAudioPlayer {
  @override
  Future<void> play(NotificationSound sound, double volume) {
    throw UnsupportedError('Notification audio is available in Flutter Web.');
  }
}
