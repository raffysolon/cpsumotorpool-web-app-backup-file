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
              title: const Text('GPS records received by the server'),
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
              GlassCard(
                child: AdminTableScroll(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Device')),
                      DataColumn(label: Text('Received (PHT)')),
                      DataColumn(label: Text('Coordinates')),
                      DataColumn(label: Text('Satellites')),
                    ],
                    rows: _records.map((record) {
                      final device = record['device'];
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              device is Map
                                  ? '${device['device_id'] ?? 'Unavailable'}'
                                  : 'Unregistered device',
                            ),
                          ),
                          DataCell(Text(_time(record['recorded_at']))),
                          DataCell(
                            Text(
                              '${record['latitude']}, ${record['longitude']}',
                            ),
                          ),
                          DataCell(
                            Text('${record['satellites'] ?? 'Unknown'}'),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
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
