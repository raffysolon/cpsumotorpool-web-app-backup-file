import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

// ═══════════════════════════════════════════════════════════════
// SYNC LOGS PAGE
// Shows GPS device sync status with refresh option
// Route: /sync-logs
// ═══════════════════════════════════════════════════════════════

// === Sync logs page: synchronization history and status ===
// ─── Page Wrapper ───
class SyncLogs extends StatelessWidget {
  const SyncLogs({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/sync-logs',
      child: const _SyncLogsContent(),
    );
  }
}

// ─── Data Model ───
class _SyncLogData {
  final String deviceId;
  final String timestamp;
  final String status; // 'Synced', 'Pending'

  const _SyncLogData({
    required this.deviceId,
    required this.timestamp,
    required this.status,
  });
}

// ─── Mock Data (replace with API/database later) ───
const _mockLogs = [
  _SyncLogData(deviceId: 'GPS-001', timestamp: '2026-08-18  14:32:05', status: 'Synced'),
  _SyncLogData(deviceId: 'GPS-002', timestamp: '2026-08-18  14:31:58', status: 'Synced'),
  _SyncLogData(deviceId: 'GPS-003', timestamp: '2026-08-18  14:28:00', status: 'Pending'),
  _SyncLogData(deviceId: 'GPS-004', timestamp: '2026-08-18  14:30:45', status: 'Synced'),
  _SyncLogData(deviceId: 'GPS-005', timestamp: '2026-08-18  14:15:10', status: 'Pending'),
  _SyncLogData(deviceId: 'GPS-006', timestamp: '2026-08-18  14:32:01', status: 'Synced'),
];

// ─── Main Content Layout ───
class _SyncLogsContent extends StatelessWidget {
  const _SyncLogsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(),
                const SizedBox(height: 16),
                _buildTable(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Top Bar (Title + Notification + Profile) ───
  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Sync Logs',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              SizedBox(height: 2),
              Text('Province of Negros Occidental — Motorpool Division',
                  style: TextStyle(fontSize: 13, color: AppColors.mutedDark)),
            ],
          ),
          const Spacer(),
          // Notification bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded,
                    size: 24, color: AppColors.navy),
                onPressed: () {},
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                      color: Colors.amber, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          // Profile avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // ─── Section Header ("GPS Sync Logs" + Refresh button) ───
  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('GPS Sync Logs',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy)),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.navy,
            side: const BorderSide(color: AppColors.border),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ─── Table Container ───
  Widget _buildTable() {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.mutedDark,
      letterSpacing: 0.8,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // ─── Table Header Row ───
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: const [
                Expanded(flex: 4, child: Text('DEVICE ID', style: headerStyle)),
                Expanded(flex: 6, child: Text('TIMESTAMP', style: headerStyle)),
                Expanded(flex: 3, child: Text('STATUS', style: headerStyle)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // ─── Table Data Rows ───
          ..._mockLogs.asMap().entries.map((entry) {
            final i = entry.key;
            final log = entry.value;
            return Column(
              children: [
                _buildRow(log),
                if (i < _mockLogs.length - 1)
                  const Divider(height: 1, color: AppColors.border),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── Table Data Row ───
  Widget _buildRow(_SyncLogData log) {
    final isSynced = log.status == 'Synced';
    final statusColor =
        isSynced ? const Color(0xFF16A34A) : const Color(0xFFD97706);
    final statusBg =
        isSynced ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Device ID
          Expanded(
            flex: 4,
            child: Text(log.deviceId,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy)),
          ),
          // Timestamp
          Expanded(
            flex: 6,
            child: Text(log.timestamp,
                style: const TextStyle(fontSize: 13, color: AppColors.navy)),
          ),
          // Status badge
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(log.status,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
