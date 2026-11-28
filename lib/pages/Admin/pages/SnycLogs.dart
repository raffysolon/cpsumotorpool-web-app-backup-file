// ignore_for_file: file_names
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/gps_sync_service.dart';
import 'package:cpsumotorpooladmin/services/gps_service.dart';
import 'package:cpsumotorpooladmin/widgets/admin_layout.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

class SyncLogs extends StatefulWidget {
  const SyncLogs({super.key, this.loadLogs});
  final Future<Map<String, dynamic>> Function(int page)? loadLogs;
  @override
  State<SyncLogs> createState() => _SyncLogsState();
}

class _SyncLogsState extends State<SyncLogs> with WidgetsBindingObserver {
  Timer? _timer;
  bool _visible = true;
  bool _loading = true;
  bool _fetching = false;
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

  Future<void> _load() async {
    if (_fetching || !mounted) return;
    setState(() => _fetching = true);
    try {
      final result =
          await (widget.loadLogs?.call(1) ??
              GpsSyncService.getLogs(1, summary: true));
      final records = (result['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _records = records;
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
          '${record.containsKey('overview_vehicle_id') ? record['overview_vehicle_id'] ?? 'unassigned-device-${record['device_registry_id'] ?? (device is Map ? device['device_id'] : null)}' : record['vehicle_id'] ?? (device is Map ? device['device_id'] : null) ?? record['device_registry_id'] ?? 'Unknown vehicle'}';
      (groups[id] ??= []).add(record);
    }
    return groups;
  }

  String _label(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Widget _vehicleRow(String id, List<Map<String, dynamic>> records, bool wide) {
    final record = records.first;
    final vehicle = record['vehicle'] is Map
        ? record['vehicle'] as Map
        : const {};
    final campus = _label(
      record['campus_name'] ?? vehicle['campus_name'],
      record['has_assignment'] == false
          ? 'No campus assignment'
          : 'Not specified in Assignments',
    );
    // This is explicitly the current assignment, not the historical trip driver.
    final drivers = records
        .map((r) {
          final driver = r['driver'];
          return driver is Map ? driver['name'] : r['driver_name'];
        })
        .where((v) => v != null && '$v'.trim().isNotEmpty)
        .toSet();
    final driverName = drivers.isEmpty
        ? 'No driver assigned'
        : drivers.join(', ');
    final vehicleName = _label(
      vehicle['name'],
      record.containsKey('overview_vehicle_id') &&
              record['overview_vehicle_id'] == null
          ? 'Device not currently assigned'
          : record['vehicle_id'] == null
          ? id
          : 'Vehicle #$id',
    );
    final plate = _label(vehicle['plate_no'], '');
    final title = plate.isEmpty ? vehicleName : '$vehicleName · $plate';
    final uploaded = _time(record['received_at'] ?? record['created_at']);
    final recentLoRa = records.any((entry) {
      if (entry['upload_source'] != 'recovered_lora') return false;
      final received = DateTime.tryParse('${entry['received_at']}');
      if (received == null) return false;
      final age = DateTime.now().difference(received);
      return !age.isNegative && age < const Duration(minutes: 2);
    });
    final uploadStatus = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(uploaded),
        if (recentLoRa) ...[
          const SizedBox(height: 4),
          const Text(
            'LoRa data received',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
    final details = OutlinedButton.icon(
      onPressed: () => _showDetails(title, record),
      icon: const Icon(Icons.visibility_outlined, size: 17),
      label: const Text('View Details'),
    );
    final name = Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
    if (wide) {
      return _desktopRow([
        name,
        Text(campus),
        Text(driverName),
        uploadStatus,
        details,
      ]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            name,
            const SizedBox(height: 12),
            _mobileField('Campus', campus),
            _mobileField('Assigned driver', driverName),
            const Text(
              'Last upload',
              style: TextStyle(color: AppColors.mutedDark, fontSize: 12),
            ),
            uploadStatus,
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerRight, child: details),
          ],
        ),
      ),
    );
  }

  Widget _mobileField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.mutedDark, fontSize: 12),
        ),
        Text(value),
      ],
    ),
  );

  Widget _desktopRow(List<Widget> cells) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            flex: i == 0 ? 3 : 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: cells[i],
            ),
          ),
        SizedBox(
          width: 148,
          child: Align(alignment: Alignment.centerRight, child: cells[4]),
        ),
      ],
    ),
  );

  Widget _overview() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 820;
      final rows = _groups.entries.map(
        (entry) => _vehicleRow(entry.key, entry.value, wide),
      );
      if (!wide)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows.toList(),
        );
      return GlassCard(
        child: Column(
          children: [
            DefaultTextStyle.merge(
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.mutedDark,
              ),
              child: _desktopRow(const [
                Text('Vehicle'),
                Text('Campus'),
                Text('Assigned driver'),
                Text('Last upload'),
                SizedBox.shrink(),
              ]),
            ),
            for (final row in rows) ...[const Divider(height: 1), row],
          ],
        ),
      );
    },
  );

  void _showDetails(String title, Map<String, dynamic> record) {
    final vehicleId = int.tryParse(
      '${record.containsKey('overview_vehicle_id') ? record['overview_vehicle_id'] : record['vehicle_id']}',
    );
    final deviceId = int.tryParse('${record['device_registry_id']}');
    showDialog<void>(
      context: context,
      builder: (_) => _SyncDetails(
        title: title,
        load: (page) =>
            widget.loadLogs?.call(page) ??
            (vehicleId == null && deviceId == null
                ? Future.value({
                    'data': [record],
                  })
                : GpsSyncService.getLogs(
                    page,
                    vehicleId: vehicleId,
                    deviceRegistryId: vehicleId == null ? deviceId : null,
                  )),
        table: _detailsTable,
      ),
    );
  }

  Widget _detailsTable(List<Map<String, dynamic>> records) => AdminTableScroll(
    child: DataTable(
      columns: const [
        DataColumn(label: Text('Device')),
        DataColumn(label: Text('Vehicle at capture')),
        DataColumn(label: Text('Captured (PHT)')),
        DataColumn(label: Text('Uploaded (PHT)')),
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
            DataCell(
              Text(
                r['recorded_vehicle'] is Map
                    ? '${r['recorded_vehicle']['name'] ?? r['vehicle_id']}'
                    : '${r['vehicle_id'] ?? 'Not recorded'}',
              ),
            ),
            DataCell(Text(_time(r['recorded_at']))),
            DataCell(Text(_time(r['received_at'] ?? r['created_at']))),
            DataCell(Text(source)),
            DataCell(Text('${r['latitude']}, ${r['longitude']}')),
          ],
        );
      }).toList(),
    ),
  );

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
              _overview(),
          ],
        ),
      ),
    ),
  );
}

class _SyncDetails extends StatefulWidget {
  const _SyncDetails({
    required this.title,
    required this.load,
    required this.table,
  });
  final String title;
  final Future<Map<String, dynamic>> Function(int) load;
  final Widget Function(List<Map<String, dynamic>>) table;

  @override
  State<_SyncDetails> createState() => _SyncDetailsState();
}

class _SyncDetailsState extends State<_SyncDetails> {
  int _page = 1;
  late Future<Map<String, dynamic>> _result = widget.load(1);

  void _go(int page) => setState(() {
    _page = page;
    _result = widget.load(page);
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: SizedBox(
      width: 920,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load upload history.'),
                TextButton(
                  onPressed: () => _go(_page),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          final data = snapshot.requireData;
          final records = (data['data'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
          final last = (data['last_page'] as num?)?.toInt() ?? 1;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (records.isEmpty)
                const Text('No GPS records received yet.')
              else
                widget.table(records),
              if (last > 1)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _page > 1 ? () => _go(_page - 1) : null,
                      child: const Text('Previous'),
                    ),
                    Text('Page $_page of $last'),
                    TextButton(
                      onPressed: _page < last ? () => _go(_page + 1) : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}
