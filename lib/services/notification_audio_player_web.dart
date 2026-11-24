// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:html' as html;

import 'notification_audio_player.dart';

NotificationAudioPlayer createNotificationAudioPlayer() =>
    _WebNotificationAudioPlayer();

class _WebNotificationAudioPlayer implements NotificationAudioPlayer {
  static const _sampleRate = 22050;
  static final Map<NotificationSound, String> _waveData = {};

  html.AudioElement? _currentAudio;

  @override
  Future<void> play(NotificationSound sound, double volume) async {
    final audio = html.AudioElement()
      ..src = _waveData.putIfAbsent(sound, () => _createWaveData(sound))
      ..preload = 'auto'
      ..volume = volume.clamp(0, 1).toDouble();
    _currentAudio = audio;

    try {
      await audio.play();
      await audio.onEnded.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => html.Event('timeout'),
      );
    } finally {
      audio.pause();
      audio.removeAttribute('src');
      audio.load();
      if (identical(_currentAudio, audio)) _currentAudio = null;
    }
  }

  static String _createWaveData(NotificationSound sound) {
    final notes = _notesFor(sound);
    final gapSamples = (_sampleRate * 0.035).round();
    final noteSamples = notes
        .map((note) => (_sampleRate * note.duration).round())
        .toList();
    final sampleCount =
        noteSamples.fold<int>(0, (total, count) => total + count) +
        gapSamples * (notes.length - 1);
    final dataLength = sampleCount * 2;
    final wave = Uint8List(44 + dataLength);
    final header = ByteData.sublistView(wave);

    wave
      ..setRange(0, 4, ascii.encode('RIFF'))
      ..setRange(8, 12, ascii.encode('WAVE'))
      ..setRange(12, 16, ascii.encode('fmt '));
    header
      ..setUint32(4, 36 + dataLength, Endian.little)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, _sampleRate, Endian.little)
      ..setUint32(28, _sampleRate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(40, dataLength, Endian.little);
    wave.setRange(36, 40, ascii.encode('data'));

    var sampleIndex = 0;
    for (var noteIndex = 0; noteIndex < notes.length; noteIndex++) {
      final note = notes[noteIndex];
      final count = noteSamples[noteIndex];
      final attackSamples = (_sampleRate * 0.008).round();
      final releaseSamples = (_sampleRate * 0.025).round();
      for (var index = 0; index < count; index++) {
        final attack = math.min(1.0, index / attackSamples);
        final release = math.min(1.0, (count - index) / releaseSamples);
        final envelope = math.min(attack, release);
        final sample =
            math.sin(2 * math.pi * note.frequency * index / _sampleRate) *
            envelope *
            0.42;
        header.setInt16(
          44 + sampleIndex * 2,
          (sample * 32767).round(),
          Endian.little,
        );
        sampleIndex++;
      }
      if (noteIndex < notes.length - 1) sampleIndex += gapSamples;
    }

    return 'data:audio/wav;base64,${base64Encode(wave)}';
  }

  static List<_Tone> _notesFor(NotificationSound sound) => switch (sound) {
    NotificationSound.unauthorizedMovement => const [
      _Tone(740, 0.11),
      _Tone(587, 0.11),
      _Tone(740, 0.14),
    ],
    NotificationSound.approvedMovementBeforeStart => const [
      _Tone(523, 0.12),
      _Tone(659, 0.16),
    ],
    NotificationSound.activeTripConnectivityWarning => const [
      _Tone(440, 0.14),
      _Tone(392, 0.18),
    ],
    NotificationSound.activeTripConnectivityRecovery => const [
      _Tone(587, 0.12),
      _Tone(784, 0.17),
    ],
    NotificationSound.scheduledDepartureReminder => const [
      _Tone(523, 0.13),
      _Tone(659, 0.16),
    ],
    NotificationSound.overdueDepartureWarning => const [
      _Tone(659, 0.12),
      _Tone(440, 0.18),
    ],
    NotificationSound.synchronizationSuccess => const [
      _Tone(587, 0.1),
      _Tone(740, 0.1),
      _Tone(880, 0.18),
    ],
    NotificationSound.synchronizationFailure => const [
      _Tone(440, 0.14),
      _Tone(349, 0.19),
    ],
  };
}

class _Tone {
  const _Tone(this.frequency, this.duration);

  final double frequency;
  final double duration;
}
