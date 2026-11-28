import 'dart:async';

import 'package:flutter/material.dart';

import '../services/gps_service.dart';
import '../services/trip_service.dart';
import 'destination_pin_dialog.dart';

class ActiveTripEta extends StatefulWidget {
  const ActiveTripEta({
    super.key,
    required this.vehicleName,
    required this.location,
    required this.onClose,
    this.trackingStatus,
  });

  final String vehicleName;
  final GpsLocation location;
  final VoidCallback onClose;
  final String? trackingStatus;

  @override
  State<ActiveTripEta> createState() => _ActiveTripEtaState();
}

class _ActiveTripEtaState extends State<ActiveTripEta> {
  late final Timer _timer;
  Map<String, dynamic>? _estimate;
  bool _fetching = false;
  bool _failed = false;
  bool _refreshAfterSave = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final estimate = await TripService.getTripEta(widget.location.trip!.id);
      if (mounted) {
        setState(() {
          _estimate = estimate;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      _fetching = false;
      if (mounted && _refreshAfterSave) {
        _refreshAfterSave = false;
        await _refresh();
      }
    }
  }

  Future<void> _setPin() async {
    final trip = widget.location.trip!;
    final selected = await showDestinationPinDialog(
      context,
      destination: trip.destination ?? 'Trip #${trip.id}',
      initialPin: null,
      savedDestinations: TripService.getSavedDestinations(),
      save: (point) => TripService.setDestinationPin(
        trip.id,
        point.latitude,
        point.longitude,
      ),
    );
    if (mounted && selected != null) {
      if (_fetching) {
        _refreshAfterSave = true;
        return;
      }
      setState(() {
        _estimate = null;
        _failed = false;
      });
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.location.trip!;
    final status = _estimate?['status'];
    final arrival = DateTime.tryParse('${_estimate?['arrival_at']}');
    final recorded = DateTime.tryParse('${_estimate?['gps_recorded_at']}');
    final latest = widget.location.recordedAt;
    final fresh = widget.location.isRecent;
    final now = DateTime.now();
    String pht(DateTime time) {
      final local = time.toUtc().add(const Duration(hours: 8));
      return '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))} PHT';
    }

    final message = switch (status) {
      'pin_missing' => 'ETA unavailable. Set the destination pin.',
      'return_leg' => 'ETA is available for the outbound leg.',
      'not_driving' =>
        'ETA will appear while the vehicle is on its outbound trip.',
      'routing_unconfigured' =>
        'ETA is unavailable until road routing is configured.',
      'gps_missing' ||
      'gps_stale' => 'ETA unavailable. Waiting for a recent GPS reading.',
      'routing_unavailable' => 'No road estimate available right now.',
      'available' when arrival != null && fresh && arrival.isAfter(now) =>
        'Estimated arrival ${pht(arrival)} · ${(arrival.difference(now).inSeconds / 60).ceil()} min left',
      'available' when arrival != null && !fresh =>
        'Last estimate ${pht(arrival)} · GPS outdated',
      'available' => 'Waiting for an updated estimate.',
      _ => 'Calculating ETA…',
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.vehicleName} · Trip #${trip.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Close trip ETA',
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            if (trip.destination case final destination?) Text(destination),
            Text(_failed ? 'Unable to load the ETA.' : message),
            if (!_failed && status == 'pin_missing')
              TextButton(onPressed: _setPin, child: const Text('Set pin')),
            if (_failed || status == 'routing_unavailable')
              TextButton(onPressed: _refresh, child: const Text('Retry ETA')),
            Text(
              (widget.trackingStatus ??
                      'Last GPS update: ${pht(latest)}${!fresh ? ' · outdated' : ''}') +
                  (recorded == null
                      ? ''
                      : '\nEstimate based on GPS at ${pht(recorded)}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
