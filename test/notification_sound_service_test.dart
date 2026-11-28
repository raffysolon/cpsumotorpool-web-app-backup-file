import 'package:cpsumotorpooladmin/services/notification_audio_player.dart';
import 'package:cpsumotorpooladmin/services/notification_sound_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

  late _FakeAudioPlayer player;
  late NotificationSoundService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = _FakeAudioPlayer();
    service = NotificationSoundService(audioPlayer: player);
  });

  test('initial notification history is never played back', () async {
    await service.savePreferences(
      'admin@example.test',
      const NotificationSoundPreferences(enabled: true),
    );
    final history = [_notification(1, 'movement:pretrip:1:2:3')];

    await service.observeNotifications(
      accountScope: 'admin@example.test',
      notifications: history,
    );
    expect(player.sounds, isEmpty);

    await service.playTestSound(0.5);
    await service.observeNotifications(
      accountScope: 'admin@example.test',
      notifications: history,
    );
    expect(player.sounds, [NotificationSound.scheduledDepartureReminder]);
  });

  test(
    'new event plays once and duplicate poll results are deduplicated',
    () async {
      final initial = [_notification(1, 'movement:pretrip:1:2:3')];
      await service.savePreferences(
        'driver@example.test',
        const NotificationSoundPreferences(enabled: true),
      );
      await service.observeNotifications(
        accountScope: 'driver@example.test',
        notifications: initial,
      );
      await service.playTestSound(0.6);

      final updated = [...initial, _notification(2, 'movement:pretrip:1:2:4')];
      await service.observeNotifications(
        accountScope: 'driver@example.test',
        notifications: updated,
      );
      await service.observeNotifications(
        accountScope: 'driver@example.test',
        notifications: updated,
      );
      await service.observeNotifications(
        accountScope: 'driver@example.test',
        notifications: [...updated, _notification(3, 'movement:pretrip:1:2:4')],
      );

      expect(player.sounds, [
        NotificationSound.scheduledDepartureReminder,
        NotificationSound.approvedMovementBeforeStart,
      ]);
    },
  );

  test('new trip notifications play by default without a sound test', () async {
    final initial = [_notification(1, 'movement:pretrip:1:2:3')];
    await service.observeNotifications(
      accountScope: 'admin@example.test',
      notifications: initial,
    );
    await service.observeNotifications(
      accountScope: 'admin@example.test',
      notifications: [...initial, _notification(2, '')],
    );

    expect(player.sounds, [NotificationSound.scheduledDepartureReminder]);
  });

  test(
    'eligible notifications stay silent while the app is suspended',
    () async {
      await service.savePreferences(
        'admin@example.test',
        const NotificationSoundPreferences(enabled: true),
      );
      final initial = [_notification(1, 'movement:pretrip:1:2:3')];
      await service.observeNotifications(
        accountScope: 'admin@example.test',
        notifications: initial,
      );
      await service.playTestSound(0.5);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      try {
        await service.observeNotifications(
          accountScope: 'admin@example.test',
          notifications: [
            ...initial,
            _notification(2, 'movement:pretrip:1:2:4'),
          ],
        );
        expect(player.sounds, [NotificationSound.scheduledDepartureReminder]);
      } finally {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
    },
  );

  test('high-priority-only mode excludes ordinary notifications', () async {
    await service.savePreferences(
      'admin@example.test',
      const NotificationSoundPreferences(enabled: true, highPriorityOnly: true),
    );
    final initial = [_notification(1, 'movement:pretrip:1:2:3')];
    await service.observeNotifications(
      accountScope: 'admin@example.test',
      notifications: initial,
    );
    await service.playTestSound(0.5);
    await service.observeNotifications(
      accountScope: 'admin@example.test',
      notifications: [...initial, _notification(2, 'movement:pretrip:1:2:4')],
    );
    await service.observeNotifications(
      accountScope: 'admin@example.test',
      notifications: [
        ...initial,
        _notification(3, 'movement:unauthorized:1:2:5', priority: 'high'),
      ],
    );

    expect(player.sounds, [
      NotificationSound.scheduledDepartureReminder,
      NotificationSound.unauthorizedMovement,
    ]);
  });

  test('account preferences and volume persist separately', () async {
    const adminPreferences = NotificationSoundPreferences(
      enabled: true,
      volume: 0.8,
      highPriorityOnly: true,
    );
    const driverPreferences = NotificationSoundPreferences(
      enabled: false,
      volume: 0.3,
    );
    await service.savePreferences('admin@example.test', adminPreferences);
    await service.savePreferences('driver@example.test', driverPreferences);

    expect(
      await service.loadPreferences('admin@example.test'),
      adminPreferences,
    );
    expect(
      await service.loadPreferences('driver@example.test'),
      driverPreferences,
    );
  });

  test('special alerts have distinct sounds and other events use the default', () {
    expect(
      NotificationSoundService.soundForNotification(
        _notification(1, 'movement:unauthorized:1:2:3', priority: 'high'),
      ),
      NotificationSound.unauthorizedMovement,
    );
    expect(
      NotificationSoundService.soundForNotification(
        _notification(2, 'movement:unauthorized:1:2:4'),
      ),
      isNull,
    );
    expect(
      NotificationSoundService.soundForNotification(
        _notification(3, 'tracker-departure-unreachable:1:2:3'),
      ),
      NotificationSound.scheduledDepartureReminder,
    );
    expect(
      NotificationSoundService.soundForNotification(
        _notification(4, 'departure-overdue:1:2:3'),
      ),
      NotificationSound.overdueDepartureWarning,
    );
    expect(
      NotificationSoundService.soundForNotification(
        _notification(5, 'trip-connectivity-recovered:1'),
      ),
      NotificationSound.scheduledDepartureReminder,
    );
    expect(
      NotificationSoundService.soundForNotification(
        _notification(6, 'sync:success:1'),
      ),
      NotificationSound.scheduledDepartureReminder,
    );
  });

  test(
    'unknown notifications and repeated bursts do not play extra sounds',
    () async {
      final initial = [_notification(1, 'ordinary-trip-update')];
      await service.savePreferences(
        'admin@example.test',
        const NotificationSoundPreferences(enabled: true),
      );
      await service.observeNotifications(
        accountScope: 'admin@example.test',
        notifications: initial,
      );
      await service.playTestSound(0.5);

      await service.observeNotifications(
        accountScope: 'admin@example.test',
        notifications: [...initial, _notification(2, 'movement:pretrip:1:2:3')],
      );
      await service.observeNotifications(
        accountScope: 'admin@example.test',
        notifications: [
          ...initial,
          _notification(2, 'movement:pretrip:1:2:3'),
          _notification(3, 'departure-overdue:1:2:3'),
        ],
      );

      expect(player.sounds, [
        NotificationSound.scheduledDepartureReminder,
        NotificationSound.approvedMovementBeforeStart,
      ]);
    },
  );
}

class _FakeAudioPlayer implements NotificationAudioPlayer {
  final List<NotificationSound> sounds = [];
  final List<double> volumes = [];

  @override
  Future<void> play(NotificationSound sound, double volume) async {
    sounds.add(sound);
    volumes.add(volume);
  }
}

Map<String, dynamic> _notification(
  int id,
  String eventKey, {
  String priority = 'normal',
}) {
  return {
    'id': id,
    'event_key': eventKey,
    'message': eventKey,
    'priority': priority,
    'created_at': '2026-11-24T13:00:00Z',
  };
}
