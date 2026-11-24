import 'package:cpsumotorpooladmin/services/notification_audio_player.dart';
import 'package:cpsumotorpooladmin/services/notification_sound_service.dart';
import 'package:cpsumotorpooladmin/widgets/notification_sound_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late _FakeAudioPlayer player;
  late NotificationSoundService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    player = _FakeAudioPlayer();
    service = NotificationSoundService(audioPlayer: player);
  });

  testWidgets('sound settings persist enable, volume, and alert filters', (
    tester,
  ) async {
    await tester.pumpWidget(_settingsHost(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notification-sounds-enabled')));
    await tester.pumpAndSettle();

    var slider = tester.widget<Slider>(
      find.byKey(const Key('notification-sound-volume')),
    );
    slider.onChanged!(0.8);
    await tester.pump();
    slider = tester.widget<Slider>(
      find.byKey(const Key('notification-sound-volume')),
    );
    slider.onChangeEnd!(0.8);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('notification-sounds-high-priority-only')),
    );
    await tester.pumpAndSettle();

    expect(
      await service.loadPreferences('admin@example.test'),
      const NotificationSoundPreferences(
        enabled: true,
        volume: 0.8,
        highPriorityOnly: true,
      ),
    );

    await tester.tap(find.byKey(const Key('notification-sound-test')));
    await tester.pumpAndSettle();
    expect(player.sounds, [NotificationSound.scheduledDepartureReminder]);
    expect(player.volumes, [0.8]);
    expect(service.isAudioUnlocked, isTrue);
    expect(
      find.text(
        'Test sound played. Notifications can sound while this app is open.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('sound settings fit mobile and desktop widths', (tester) async {
    for (final size in [const Size(360, 800), const Size(900, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_settingsHost(service));
      await tester.pumpAndSettle();

      expect(find.text('Enable notification sounds'), findsOneWidget);
      expect(find.text('High-priority alerts only'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.reset();
    }
  });
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

Widget _settingsHost(NotificationSoundService service) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: NotificationSoundSettings(
              accountScope: 'admin@example.test',
              service: service,
            ),
          ),
        ),
      ),
    ),
  );
}
