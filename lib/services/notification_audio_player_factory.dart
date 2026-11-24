import 'notification_audio_player.dart';
import 'notification_audio_player_stub.dart'
    if (dart.library.html) 'notification_audio_player_web.dart'
    as platform;

NotificationAudioPlayer createNotificationAudioPlayer() =>
    platform.createNotificationAudioPlayer();
