// ignore_for_file: file_names
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/gps_sync_service.dart';
import 'package:cpsumotorpooladmin/services/gps_service.dart';
import 'package:cpsumotorpooladmin/widgets/admin_layout.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

class SyncLogs extends StatefulWidget {
  const SyncLogs({super.key, this.loadLogs = GpsSyncService.getLogs});
  final Future<Map<String, dynamic>> Function(int page) loadLogs;
  @override
  State<SyncLogs> createState() => _SyncLogsState();
}

class _SyncLogsState extends State<SyncLogs> with WidgetsBindingObserver {
  Timer? _timer;
  bool _visible = true;
  bool _loading = true;
  bool _fetching = false;
  int _page = 1;
  int _lastPage = 1;
  String? _error;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _visible && ModalRoute.of(context)?.isCurrent != false) {
        _load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
  }

  Future<void> _load([int? page]) async {
    if (_fetching || !mounted) return;
    setState(() => _fetching = true);
    final requestedPage = page ?? _page;
    try {
      final result = await widget.loadLogs(requestedPage);
      final records = (result['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _records = records;
        _page = requestedPage;
        _lastPage = (result['last_page'] as num?)?.toInt() ?? 1;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        if (error is GpsAccessException) _records = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _fetching = false;
          _loading = false;
        });
      }
    }
  }

  String _time(dynamic value) {
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return 'Unavailable';
    final pht = parsed.toUtc().add(const Duration(hours: 8));
    return '${pht.toIso8601String().substring(0, 19).replaceFirst('T', ' ')} PHT';
  }

  Map<String, List<Map<String, dynamic>>> get _groups {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final record in _records) {
      final device = record['device'];
      final id =
          '${record['vehicle_id'] ?? (device is Map ? device['device_id'] : null) ?? record['device_registry_id'] ?? 'Unknown vehicle'}';
      (groups[id] ??= []).add(record);
    }
    return groups;
  }

  String _label(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Widget _vehicleCard(String id, List<Map<String, dynamic>> records) {
    final record = records.first;
    final vehicle = record['vehicle'] is Map
        ? record['vehicle'] as Map
        : const {};
    final campus = _label(
      record['campus_name'] ?? vehicle['campus_name'],
      'Not available',
    );
    // Do not infer a historical driver from the vehicle's current assignment.
    final drivers = records
        .map((r) {
          final driver = r['driver'];
          return driver is Map ? driver['name'] : r['driver_name'];
        })
        .where((v) => v != null && '$v'.trim().isNotEmpty)
        .toSet();
    final driverName = drivers.isEmpty ? 'Not available' : drivers.join(', ');
    final vehicleName = _label(
      vehicle['name'],
      record['vehicle_id'] == null ? id : 'Vehicle #$id',
    );
    final plate = _label(vehicle['plate_no'], '');
    final recovered = records
        .where((r) => r['upload_source'] == 'recovered_lora')
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            key: ValueKey('sync-vehicle-$id'),
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            childrenPadding: const EdgeInsets.only(bottom: 16),
            title: Text(
              plate.isEmpty ? vehicleName : '$vehicleName · $plate',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Campus: $campus'),
                  Text('Driver: $driverName'),
                  const SizedBox(height: 8),
                  Text(
                    '${records.length} saved records on this page · $recovered via LoRa',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Saved to cloud'),
                subtitle: Text(
                  'These records are already in the database. Pending SD records and transfer completion are not yet reported.',
                ),
              ),
              AdminTableScroll(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Device')),
                    DataColumn(label: Text('Captured (PHT)')),
                    DataColumn(label: Text('Received (PHT)')),
                    DataColumn(label: Text('Source')),
                    DataColumn(label: Text('Coordinates')),
                  ],
                  rows: records.map((r) {
                    final device = r['device'];
                    final source = switch (r['upload_source']) {
                      'recovered_lora' => 'LoRa recovery',
                      'recovered_lte' => 'LTE recovery',
                      'live_lte' => 'Live LTE',
                      _ => 'Not recorded',
                    };
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            device is Map
                                ? _label(device['device_id'], 'Unknown')
                                : 'Unknown',
                          ),
                        ),
                        DataCell(Text(_time(r['recorded_at']))),
                        DataCell(Text(_time(r['received_at']))),
                        DataCell(Text(source)),
                        DataCell(Text('${r['latitude']}, ${r['longitude']}')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppShell(
    currentRoute: '/sync-logs',
    child: AdminPageScaffold(
      title: 'Sync Logs',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminToolbar(
              title: const Text('Vehicle sync overview'),
              actions: OutlinedButton.icon(
                onPressed: _fetching ? null : () => _load(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Uploaded records grouped by vehicle on this page. Open a vehicle to view its records.',
              style: TextStyle(color: AppColors.mutedDark),
            ),
            const SizedBox(height: 8),
            const Text('Live sync progress is not available yet.'),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_records.isEmpty && _error == null)
              const Text('No GPS records received yet.')
            else if (_records.isNotEmpty)
              ..._groups.entries.map(
                (entry) => _vehicleCard(entry.key, entry.value),
              ),
            if (_lastPage > 1)
              Wrap(
                children: [
                  TextButton(
                    onPressed: _fetching || _page <= 1
                        ? null
                        : () => _load(_page - 1),
                    child: const Text('Previous'),
                  ),
                  Text('Page $_page of $_lastPage'),
                  TextButton(
                    onPressed: _fetching || _page >= _lastPage
                        ? null
                        : () => _load(_page + 1),
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
