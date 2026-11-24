import 'package:flutter/material.dart';

import '../pages/services/auth_service.dart';
import '../services/notification_sound_service.dart';

class NotificationSoundSettings extends StatefulWidget {
  const NotificationSoundSettings({super.key, this.accountScope, this.service});

  final String? accountScope;
  final NotificationSoundService? service;

  @override
  State<NotificationSoundSettings> createState() =>
      _NotificationSoundSettingsState();
}

class _NotificationSoundSettingsState extends State<NotificationSoundSettings> {
  late final NotificationSoundService _service;
  NotificationSoundPreferences _preferences =
      const NotificationSoundPreferences();
  String? _accountScope;
  String? _error;
  String? _soundMessage;
  bool _isLoading = true;
  bool _isTesting = false;
  bool _audioReady = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? NotificationSoundService.instance;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final scope =
          widget.accountScope ??
          await AuthService.getNotificationAccountScope();
      if (scope == null || scope.isEmpty) {
        throw StateError('Sign in to configure notification sounds.');
      }
      final preferences = await _service.initializeAccount(scope);
      if (!mounted) return;
      setState(() {
        _accountScope = scope;
        _preferences = preferences;
        _audioReady = _service.isAudioUnlocked;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load notification sound preferences: $error';
      });
    }
  }

  Future<void> _save(NotificationSoundPreferences next) async {
    final scope = _accountScope;
    if (scope == null) return;
    final previous = _preferences;
    setState(() {
      _preferences = next;
      _error = null;
    });
    try {
      await _service.savePreferences(scope, next);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preferences = previous;
        _error = 'Unable to save notification sound preferences: $error';
      });
    }
  }

  Future<void> _testSound() async {
    if (_isTesting) return;
    setState(() {
      _isTesting = true;
      _soundMessage = null;
      _error = null;
    });

    final played = await _service.playTestSound(_preferences.volume);
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _audioReady = played;
      _soundMessage = played
          ? 'Test sound played. Notifications can sound while this app is open.'
          : _service.lastPlaybackError == null
          ? 'The browser blocked audio. Tap Test sound again after allowing audio.'
          : 'Audio could not play: ${_service.lastPlaybackError}';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _accountScope == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 440;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: const Key('notification-sounds-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable notification sounds'),
              subtitle: const Text(
                'Play a short tone for new movement and departure alerts.',
              ),
              value: _preferences.enabled,
              onChanged: (enabled) =>
                  _save(_preferences.copyWith(enabled: enabled)),
            ),
            const SizedBox(height: 8),
            Text(
              'Volume: ${(_preferences.volume * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              key: const Key('notification-sound-volume'),
              value: _preferences.volume,
              min: 0,
              max: 1,
              divisions: 10,
              label: '${(_preferences.volume * 100).round()}%',
              onChanged: (volume) => setState(
                () => _preferences = _preferences.copyWith(volume: volume),
              ),
              onChangeEnd: (volume) =>
                  _save(_preferences.copyWith(volume: volume)),
            ),
            SwitchListTile(
              key: const Key('notification-sounds-high-priority-only'),
              contentPadding: EdgeInsets.zero,
              title: const Text('High-priority alerts only'),
              subtitle: const Text(
                'Ignore ordinary pre-departure and scheduled alerts.',
              ),
              value: _preferences.highPriorityOnly,
              onChanged: (enabled) =>
                  _save(_preferences.copyWith(highPriorityOnly: enabled)),
            ),
            const SizedBox(height: 8),
            if (compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _testButton(),
                  const SizedBox(height: 8),
                  _audioStatus(context, textAlign: TextAlign.left),
                ],
              )
            else
              Row(
                children: [
                  _testButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _audioStatus(context, textAlign: TextAlign.end),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            const Text(
              'Sounds play only while this app is open and active. They do not '
              'play when the browser is closed or suspended.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            if (_soundMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _soundMessage!,
                key: const Key('notification-sound-feedback'),
                style: TextStyle(
                  color: _audioReady
                      ? Colors.green.shade800
                      : Colors.orange.shade900,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade800)),
            ],
          ],
        );
      },
    );
  }

  Widget _testButton() => FilledButton.icon(
    key: const Key('notification-sound-test'),
    onPressed: _isTesting ? null : _testSound,
    icon: _isTesting
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.volume_up_outlined),
    label: Text(_isTesting ? 'Testing...' : 'Test sound'),
  );

  Widget _audioStatus(BuildContext context, {required TextAlign textAlign}) =>
      Text(
        _audioReady
            ? 'Browser audio is enabled for this session.'
            : 'Tap Test sound once to allow playback in this browser.',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: textAlign,
      );
}
