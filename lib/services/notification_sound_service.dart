import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'notification_audio_player.dart';
import 'notification_audio_player_factory.dart';

@immutable
class NotificationSoundPreferences {
  const NotificationSoundPreferences({
    this.enabled = true,
    this.volume = 0.6,
    this.highPriorityOnly = false,
  });

  final bool enabled;
  final double volume;
  final bool highPriorityOnly;

  NotificationSoundPreferences copyWith({
    bool? enabled,
    double? volume,
    bool? highPriorityOnly,
  }) {
    return NotificationSoundPreferences(
      enabled: enabled ?? this.enabled,
      volume: volume ?? this.volume,
      highPriorityOnly: highPriorityOnly ?? this.highPriorityOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationSoundPreferences &&
      other.enabled == enabled &&
      other.volume == volume &&
      other.highPriorityOnly == highPriorityOnly;

  @override
  int get hashCode => Object.hash(enabled, volume, highPriorityOnly);
}

class NotificationSoundService {
  NotificationSoundService({
    NotificationAudioPlayer? audioPlayer,
    Future<SharedPreferences> Function()? preferencesProvider,
  }) : _audioPlayer = audioPlayer ?? createNotificationAudioPlayer(),
       _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance;

  static final instance = NotificationSoundService();

  static const _preferencePrefix = 'notification_sounds_v1';
  static const _minimumAlertInterval = Duration(seconds: 3);

  final NotificationAudioPlayer _audioPlayer;
  final Future<SharedPreferences> Function() _preferencesProvider;

  Future<void> _observationQueue = Future<void>.value();
  String? _activeAccount;
  String? _preferencesLoadingAccount;
  Future<NotificationSoundPreferences>? _preferencesLoad;
  NotificationSoundPreferences _activePreferences =
      const NotificationSoundPreferences();
  final Set<String> _seenNotificationKeys = {};
  bool _hasInitialSnapshot = false;
  bool _audioUnlocked = false;
  bool _isPlaying = false;
  DateTime? _lastPlaybackAt;
  String? _lastPlaybackError;

  String? get lastPlaybackError => _lastPlaybackError;
  bool get isAudioUnlocked => _audioUnlocked;

  Future<NotificationSoundPreferences> loadPreferences(
    String accountScope,
  ) async {
    final preferences = await _preferencesProvider();
    final prefix = _keyPrefix(accountScope);
    return NotificationSoundPreferences(
      enabled: preferences.getBool('$prefix.enabled') ?? true,
      volume: (preferences.getDouble('$prefix.volume') ?? 0.6)
          .clamp(0.0, 1.0)
          .toDouble(),
      highPriorityOnly:
          preferences.getBool('$prefix.high_priority_only') ?? false,
    );
  }

  Future<NotificationSoundPreferences> initializeAccount(
    String accountScope,
  ) async {
    final accountKey = _accountKey(accountScope);
    if (_activeAccount != accountKey) {
      _activeAccount = accountKey;
      _seenNotificationKeys.clear();
      _hasInitialSnapshot = false;
      _audioUnlocked = false;
      _lastPlaybackAt = null;
      _lastPlaybackError = null;
      _preferencesLoadingAccount = accountKey;
      final load = loadPreferences(accountScope);
      _preferencesLoad = load;
      final loaded = await load;
      if (_activeAccount == accountKey) {
        _activePreferences = loaded;
        _preferencesLoadingAccount = null;
        _preferencesLoad = null;
      }
      return loaded;
    }

    if (_preferencesLoadingAccount == accountKey) {
      final load = _preferencesLoad;
      if (load != null) {
        final loaded = await load;
        if (_activeAccount == accountKey) _activePreferences = loaded;
        return loaded;
      }
    }
    return _activePreferences;
  }

  Future<void> savePreferences(
    String accountScope,
    NotificationSoundPreferences value,
  ) async {
    final preferences = await _preferencesProvider();
    final prefix = _keyPrefix(accountScope);
    final normalized = value.copyWith(
      volume: value.volume.clamp(0.0, 1.0).toDouble(),
    );
    await preferences.setBool('$prefix.enabled', normalized.enabled);
    await preferences.setDouble('$prefix.volume', normalized.volume);
    await preferences.setBool(
      '$prefix.high_priority_only',
      normalized.highPriorityOnly,
    );
    if (_activeAccount == _accountKey(accountScope)) {
      _activePreferences = normalized;
    }
  }

  Future<void> observeNotifications({
    required String accountScope,
    required List<Map<String, dynamic>> notifications,
  }) {
    final next = _observationQueue.then(
      (_) => _observeNotifications(
        accountScope: accountScope,
        notifications: notifications,
      ),
    );
    _observationQueue = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Notification sound observation failed: $error');
      },
    );
    return next;
  }

  Future<bool> playTestSound(double volume) async {
    if (_isPlaying) {
      _lastPlaybackError = 'A notification sound is already playing.';
      return false;
    }
    return _play(
      NotificationSound.scheduledDepartureReminder,
      volume,
      unlock: true,
    );
  }

  Future<void> _observeNotifications({
    required String accountScope,
    required List<Map<String, dynamic>> notifications,
  }) async {
    await initializeAccount(accountScope);

    final newNotifications = <Map<String, dynamic>>[];
    for (final notification in notifications) {
      final key = _notificationKey(notification);
      if (key == null) continue;
      if (_seenNotificationKeys.add(key) && _hasInitialSnapshot) {
        newNotifications.add(notification);
      }
    }
    if (!_hasInitialSnapshot) {
      _hasInitialSnapshot = true;
      return;
    }
    if (!_activePreferences.enabled ||
        _isPlaying ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final candidates = newNotifications
        .map(
          (notification) => (
            notification: notification,
            sound: soundForNotification(notification),
          ),
        )
        .where(
          (candidate) =>
              candidate.sound != null &&
              (!_activePreferences.highPriorityOnly ||
                  notificationIsHighPriority(candidate.notification)),
        )
        .toList();
    if (candidates.isEmpty) return;

    candidates.sort((first, second) {
      final priority = _soundRank(
        second.sound!,
      ).compareTo(_soundRank(first.sound!));
      if (priority != 0) return priority;
      return _createdAt(
        second.notification,
      ).compareTo(_createdAt(first.notification));
    });

    final lastPlayedAt = _lastPlaybackAt;
    if (lastPlayedAt != null &&
        DateTime.now().difference(lastPlayedAt) < _minimumAlertInterval) {
      return;
    }
    await _play(
      candidates.first.sound!,
      _activePreferences.volume,
      unlock: false,
    );
  }

  Future<bool> _play(
    NotificationSound sound,
    double volume, {
    required bool unlock,
  }) async {
    _isPlaying = true;
    if (!unlock) _lastPlaybackAt = DateTime.now();
    _lastPlaybackError = null;
    try {
      await _audioPlayer.play(sound, volume.clamp(0.0, 1.0).toDouble());
      _audioUnlocked = true;
      return true;
    } catch (error) {
      _audioUnlocked = false;
      _lastPlaybackError = error.toString();
      debugPrint('Notification sound playback failed: $error');
      return false;
    } finally {
      _isPlaying = false;
    }
  }

  static NotificationSound? soundForNotification(
    Map<String, dynamic> notification,
  ) {
    final eventKey = notification['event_key']?.toString() ?? '';
    if (eventKey.startsWith('movement:unauthorized:')) {
      return notificationIsHighPriority(notification)
          ? NotificationSound.unauthorizedMovement
          : null;
    }
    if (eventKey.startsWith('movement:pretrip:')) {
      return NotificationSound.approvedMovementBeforeStart;
    }
    if (eventKey.startsWith('tracker-departure-unreachable:')) {
      return NotificationSound.scheduledDepartureReminder;
    }
    if (eventKey.startsWith('departure-overdue:')) {
      return NotificationSound.overdueDepartureWarning;
    }
    return NotificationSound.scheduledDepartureReminder;
  }

  static bool notificationIsHighPriority(Map<String, dynamic> notification) =>
      notification['priority']?.toString().toLowerCase() == 'high';

  String? _notificationKey(Map<String, dynamic> notification) {
    final eventKey = notification['event_key']?.toString().trim() ?? '';
    if (eventKey.isNotEmpty) return 'event:$eventKey';

    final id = notification['id']?.toString().trim() ?? '';
    return id.isEmpty ? null : 'id:$id';
  }

  DateTime _createdAt(Map<String, dynamic> notification) =>
      DateTime.tryParse(notification['created_at']?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  int _soundRank(NotificationSound sound) => switch (sound) {
    NotificationSound.unauthorizedMovement => 4,
    NotificationSound.overdueDepartureWarning => 3,
    NotificationSound.scheduledDepartureReminder => 2,
    NotificationSound.approvedMovementBeforeStart => 1,
    NotificationSound.activeTripConnectivityWarning ||
    NotificationSound.activeTripConnectivityRecovery ||
    NotificationSound.synchronizationSuccess ||
    NotificationSound.synchronizationFailure => 0,
  };

  String _keyPrefix(String accountScope) =>
      '$_preferencePrefix.${_accountKey(accountScope)}';

  String _accountKey(String accountScope) {
    final bytes = utf8.encode(
      '${ApiConfig.storageNamespace}|${accountScope.trim().toLowerCase()}',
    );
    final mask = BigInt.parse('18446744073709551615');
    var hash = BigInt.parse('14695981039346656037');
    final prime = BigInt.parse('1099511628211');
    for (final byte in bytes) {
      hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
