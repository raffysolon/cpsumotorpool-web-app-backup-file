import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/notification_service.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';

import 'History.dart';
import 'MyTrips.dart';
import 'ScheduleTrip.dart';

// === Driver dashboard page ===
// Route: /driver-dashboard

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with WidgetsBindingObserver {
  static const _green = AppColors.primary;
  static const _greenDark = AppColors.primaryDark;
  static const _greenSoft = Color(0xFFE8F5EC);
  static const _ink = AppColors.navy;
  static const _muted = AppColors.mutedDark;
  static const _line = AppColors.border;

  bool _isLoadingActiveTrip = true;
  bool _isLoadingTripCounts = true;
  bool _isPageVisible = true;
  bool _isRefreshRunning = false;
  Map<String, dynamic>? _activeTrip;
  int _myTripsCount = 0;
  int _scheduledTripsCount = 0;
  int _historyTripsCount = 0;
  int _notificationCount = 0;
  String _driverFirstName = 'Driver';
  List<Map<String, dynamic>> _notifications = const [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadActiveTrip();
    _loadTripCounts();
    _loadNotifications();
    _loadDriverName();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || !_isPageVisible || _isRefreshRunning) {
        return;
      }
      _loadActiveTrip(background: true);
      _loadTripCounts(background: true);
      _loadNotifications(background: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isPageVisible = true;
      if (!_isRefreshRunning) {
        _loadActiveTrip(background: true);
        _loadTripCounts(background: true);
        _loadNotifications(background: true);
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _isPageVisible = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadDriverName() async {
    final name = (await AuthService.getName())?.trim() ?? '';
    if (!mounted || name.isEmpty) return;
    setState(() {
      _driverFirstName = name.split(RegExp(r'\s+')).first;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadNotifications();
  }

  Future<void> _loadActiveTrip({bool background = false}) async {
    if (background) {
      if (_isRefreshRunning || !mounted || !_isPageVisible) {
        return;
      }
      _isRefreshRunning = true;
    }

    try {
      final result = await TripService.getMyTrips();
      final trips = result is List ? result : const [];
      Map<String, dynamic>? nextActiveTrip;
      for (final trip in trips.whereType<Map>()) {
        final status = (trip['effective_status'] ?? trip['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (status == 'active') {
          nextActiveTrip = Map<String, dynamic>.from(trip);
          break;
        }
        if (status == 'scheduled' && nextActiveTrip == null) {
          nextActiveTrip = Map<String, dynamic>.from(trip);
        }
      }

      if (!mounted) return;
      final changed = _activeTrip == null && nextActiveTrip == null
          ? false
          : _activeTrip != nextActiveTrip;
      if (!background || changed) {
        setState(() {
          _activeTrip = nextActiveTrip;
          _isLoadingActiveTrip = false;
        });
      }
    } catch (_) {
      if (background) return;
      if (!mounted) return;
      setState(() {
        _activeTrip = null;
        _isLoadingActiveTrip = false;
      });
    } finally {
      if (background) {
        _isRefreshRunning = false;
      }
    }
  }

  Future<void> _loadTripCounts({bool background = false}) async {
    try {
      final allTrips = await TripService.getMyTrips();
      final rawTrips = allTrips is List ? allTrips : const [];
      final visibleMyTrips = rawTrips.whereType<Map>().where((trip) {
        final status = (trip['effective_status'] ?? trip['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return status != 'active' && status != 'completed';
      }).toList();
      final completedTrips = rawTrips.whereType<Map>().where((trip) {
        final status = (trip['effective_status'] ?? trip['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return status == 'completed';
      }).toList();
      final approvedNotifications = rawTrips
          .whereType<Map>()
          .where((trip) {
            final status = (trip['effective_status'] ?? trip['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            return status == 'approved' ||
                status == 'scheduled' ||
                status == 'active';
          })
          .map<Map<String, String>>((trip) {
            final origin = (trip['origin'] ?? 'Origin').toString();
            final destination = (trip['destination'] ?? 'Destination')
                .toString();
            final route = '$origin to $destination';
            final status =
                (trip['effective_status'] ?? trip['status'] ?? 'approved')
                    .toString();
            return {
              'title': 'Trip update',
              'message': route,
              'time': status.toUpperCase(),
            };
          })
          .toList();
      if (!mounted) return;

      final nextMyTripsCount = visibleMyTrips.length;
      final nextScheduledTripsCount = rawTrips.whereType<Map>().where((trip) {
        final status = (trip['effective_status'] ?? trip['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return status == 'scheduled';
      }).length;
      final nextHistoryTripsCount = completedTrips.length;
      final nextNotifications = approvedNotifications;

      if (!background ||
          _myTripsCount != nextMyTripsCount ||
          _scheduledTripsCount != nextScheduledTripsCount ||
          _historyTripsCount != nextHistoryTripsCount ||
          _notifications.length != nextNotifications.length) {
        setState(() {
          _myTripsCount = nextMyTripsCount;
          _scheduledTripsCount = nextScheduledTripsCount;
          _historyTripsCount = nextHistoryTripsCount;
          _notifications = nextNotifications;
          _isLoadingTripCounts = false;
        });
      }
    } catch (_) {
      if (background) return;
      if (!mounted) return;
      setState(() {
        _myTripsCount = 0;
        _scheduledTripsCount = 0;
        _historyTripsCount = 0;
        _notifications = const [];
        _isLoadingTripCounts = false;
      });
    }
  }

  Future<void> _loadNotifications({bool background = false}) async {
    try {
      final countResult = await NotificationService.getUnreadCount();
      final listResult = await NotificationService.getNotifications();

      final count = countResult is Map ? (countResult['count'] ?? 0) as int : 0;
      final notifications = (listResult is List ? listResult : const [])
          .whereType<Map>()
          .map<Map<String, dynamic>>(
            (item) => {
              'id': item['id'] ?? 0,
              'message': item['message'] ?? 'Notification',
              'created_at': item['created_at'] ?? '',
            },
          )
          .toList();

      if (!mounted) return;

      if (!background ||
          _notificationCount != count ||
          _notifications.length != notifications.length) {
        setState(() {
          _notificationCount = count;
          _notifications = notifications;
        });
      }
    } catch (_) {
      if (background) return;
      if (!mounted) return;
      setState(() {
        _notificationCount = 0;
        _notifications = const [];
      });
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Notifications'),
          content: SizedBox(
            width: 420,
            child: _notifications.isEmpty
                ? const Text('No notifications.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final id = (notification['id'] ?? 0) as int;
                      final message = (notification['message'] ?? '')
                          .toString();
                      final relativeTime = _relativeTime(
                        (notification['created_at'] ?? '').toString(),
                      );

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _greenSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: _green,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          message,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: Text(
                          relativeTime,
                          style: const TextStyle(fontSize: 10, color: _muted),
                        ),
                        onTap: () async {
                          try {
                            await NotificationService.markAsRead(id);
                            if (mounted) {
                              await _loadNotifications();
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _relativeTime(String value) {
    if (value.isEmpty) return 'Just now';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Just now';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}';
  }

  String _formatDeparture(String? value) {
    if (value == null || value.isEmpty) return '—';
    try {
      final parsed = DateTime.tryParse(value)?.toLocal();
      if (parsed == null) return value;
      final month = _monthShort(parsed.month);
      final day = parsed.day;
      final year = parsed.year;
      final hour = parsed.hour;
      final minute = parsed.minute.toString().padLeft(2, '0');
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '$month $day, $year • $formattedHour:$minute $suffix';
    } catch (_) {
      return value;
    }
  }

  String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _routeText(Map<String, dynamic>? trip) {
    if (trip == null) return 'No active trip';
    final origin = (trip['origin'] ?? '').toString();
    final destination = (trip['destination'] ?? '').toString();
    if (origin.isEmpty && destination.isEmpty) return 'Trip in progress';
    if (origin.isEmpty) return destination;
    if (destination.isEmpty) return origin;
    return '$origin to $destination';
  }

  String _activeActionLabel(Map<String, dynamic> trip) {
    final tripStatus = '${trip['status'] ?? trip['effective_status'] ?? ''}'
      .trim()
      .toLowerCase();
    final movements =
        (trip['movements'] is List ? trip['movements'] as List : const [])
            .whereType<Map>()
            .toList();
    final outboundMatches = movements
        .where((item) => '${item['movement_no']}' == '1')
        .toList();
    final returnMatches = movements
        .where((item) => '${item['movement_no']}' == '2')
        .toList();
    final outbound = outboundMatches.isEmpty ? null : outboundMatches.first;
    final returnMovement = returnMatches.isEmpty ? null : returnMatches.first;
    if (tripStatus == 'active' && '${outbound?['status'] ?? ''}' != 'completed') {
      return 'End Trip';
    }
    if ('${returnMovement?['status'] ?? ''}' == 'active') {
      return 'End Return Trip';
    }
    if ('${outbound?['status'] ?? ''}' == 'scheduled') {
      return 'Start Trip';
    }
    if ('${outbound?['status'] ?? ''}' == 'active') {
      return 'End Trip';
    }
    if ('${outbound?['status'] ?? ''}' == 'completed') {
      return 'Start Return Trip';
    }
    return 'Start Trip';
  }

  Widget _buildCurrentActiveTripCard() {
    if (_isLoadingActiveTrip) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 248),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 18,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_activeTrip == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 248),
        child: GlassCard(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          borderRadius: 18,
          child: const Center(
          child: Text(
            'No active trip right now',
            style: TextStyle(
              color: _muted,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          ),
        ),
      );
    }

    final trip = _activeTrip!;
    final vehicle = trip['vehicle'] is Map
      ? Map<String, dynamic>.from(trip['vehicle'] as Map)
      : const <String, dynamic>{};
    final vehicleLabel = _vehicleLabel(vehicle);
    final route = _routeText(trip);
    final actionLabel = _activeActionLabel(trip);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Active Trip',
                style: TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _greenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: _greenDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            route,
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 19),
          const Divider(color: _line, height: 1),
          const SizedBox(height: 16),
          _buildTripDetails(
            vehicle: vehicleLabel,
            departure: _formatDeparture(
              trip['scheduled_departure']?.toString(),
            ),
            status: 'In Progress',
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _showEndTripDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  String _vehicleLabel(Map<String, dynamic> vehicle) {
    final name = vehicle['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final plateNumber = vehicle['plate_no']?.toString().trim() ?? '';
    return plateNumber.isNotEmpty ? plateNumber : '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DriverShellAtmosphere(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final padding = narrow ? 20.0 : 42.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, 24, padding, 42),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(narrow: narrow),
                  SizedBox(height: narrow ? 28 : 36),
                  _buildWelcome(),
                  const SizedBox(height: 28),
                  _buildMainGrid(narrow: narrow),
                  const SizedBox(height: 24),
                  _buildQuickActions(narrow: narrow),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar({required bool narrow}) {
    if (narrow) {
      return Row(
        children: [
          _buildBrandMark(size: 34),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'CPSU MOTORPOOL',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: _showNotificationsDialog,
            icon: Badge(
              label: Text(
                _notificationCount > 9 ? '9+' : _notificationCount.toString(),
              ),
              backgroundColor: _green,
              isLabelVisible: _notificationCount > 0,
              child: const Icon(Icons.notifications_none_rounded, color: _ink),
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: _greenDark),
          ),
        ],
      );
    }

    return Row(
      children: [
        Container(
          width: narrow ? 34 : 42,
          height: narrow ? 34 : 42,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.local_shipping_rounded,
            color: Colors.white,
            size: narrow ? 19 : 23,
          ),
        ),
        const SizedBox(width: 11),
        const Text(
          'CPSU MOTORPOOL',
          style: TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Notifications',
          onPressed: _showNotificationsDialog,
          icon: Badge(
            label: Text(
              _notificationCount > 9 ? '9+' : _notificationCount.toString(),
            ),
            backgroundColor: _green,
            isLabelVisible: _notificationCount > 0,
            child: const Icon(Icons.notifications_none_rounded, color: _ink),
          ),
        ),
        const SizedBox(width: 10),
        _buildAccountBox(narrow: narrow),
      ],
    );
  }

  Widget _buildBrandMark({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.local_shipping_rounded,
        color: Colors.white,
        size: size * .55,
      ),
    );
  }

  Widget _buildAccountBox({required bool narrow}) {
    return Container(
      padding: EdgeInsets.fromLTRB(narrow ? 6 : 10, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D19332A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: _greenSoft,
            child: Icon(Icons.person, color: _green, size: 19),
          ),
          if (!narrow) ...[
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver Account',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'CPSU Driver',
                  style: TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ],
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/driver-settings'),
            icon: const Icon(Icons.settings_outlined, color: _muted, size: 19),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: _greenDark, size: 19),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome, $_driverFirstName!',
          style: TextStyle(
            color: _ink,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'What would you like to do today?',
          style: TextStyle(color: _muted, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildMainGrid({required bool narrow}) {
    if (narrow) {
      return Column(
        children: [
          _buildCreateTripCard(),
          const SizedBox(height: 18),
          _buildActiveTripCard(narrow: narrow),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildCreateTripCard()),
        const SizedBox(width: 22),
        Expanded(flex: 7, child: _buildCurrentActiveTripCard()),
      ],
    );
  }

  Widget _buildCreateTripCard() {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/driver-create-trip'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 248,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _green,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
              BoxShadow(
                color: AppColors.brandDeep.withValues(alpha: 0.18),
              blurRadius: 15,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: _green, size: 43),
            ),
            const SizedBox(height: 18),
            const Text(
              'Create Trip Ticket',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Start a new trip request',
              style: TextStyle(color: Color(0xFFD7F4E5), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripCard({required bool narrow}) {
    return _buildCurrentActiveTripCard();
  }

  Future<void> _showEndTripDialog() async {
    final tripId = int.tryParse('${_activeTrip?['id'] ?? ''}');
    if (tripId == null) return;
    final actionLabel = _activeActionLabel(_activeTrip!);

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            actionLabel,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          content: Text(
            actionLabel == 'Start Trip'
                ? 'The system will record the departure time automatically.'
                : actionLabel == 'Start Return Trip'
                ? 'The system will record the return departure time automatically.'
                : 'The system will record the current arrival time automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    if (shouldEnd != true || !mounted) return;

    try {
      if (actionLabel == 'Start Trip') {
        await TripService.startTrip(tripId);
      } else if (actionLabel == 'Start Return Trip') {
        await TripService.startReturnTrip(tripId);
      } else if (actionLabel == 'End Return Trip') {
        await TripService.endReturnTrip(tripId);
      } else {
        await TripService.endTrip(tripId);
      }
      await _loadActiveTrip();
      await _loadTripCounts();
      if (!mounted) return;
      final successMessage = actionLabel == 'Start Trip'
          ? 'Trip started. Departure time was recorded automatically.'
          : actionLabel == 'Start Return Trip'
          ? 'Return trip started. Departure time was recorded automatically.'
          : actionLabel == 'End Return Trip'
          ? 'Return trip ended. Arrival time was recorded automatically.'
          : 'Trip ended. Arrival time was recorded automatically.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to end trip: $error')));
    }
  }

  Widget _buildTripDetails({
    required String vehicle,
    required String departure,
    required String status,
    bool narrow = false,
  }) {
    final details = [
      _buildTripDetail('VEHICLE', vehicle, expanded: !narrow),
      _buildTripDetail('DEPARTURE', departure, expanded: !narrow),
      _buildTripDetail('STATUS', status, expanded: !narrow),
    ];
    return narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: details,
          )
        : Row(children: details);
  }

  Widget _buildTripDetail(String label, String value, {bool expanded = true}) {
    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: _greenDark,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
    return expanded ? Expanded(child: detail) : detail;
  }

  Widget _buildQuickActions({required bool narrow}) {
    final cards = [
      _buildActionCard(
        Icons.receipt_long_outlined,
        'My Trips',
        'Pending & completed',
        count: _isLoadingTripCounts ? null : _myTripsCount,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyTripsPage()),
        ),
      ),
      _buildActionCard(
        Icons.history_rounded,
        'History',
        'Past trips',
        count: _isLoadingTripCounts ? null : _historyTripsCount,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryPage()),
        ),
      ),
      _buildActionCard(
        Icons.schedule_outlined,
        'Scheduled Trips',
        'Upcoming trips',
        count: _isLoadingTripCounts ? null : _scheduledTripsCount,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScheduleTripPage()),
        ),
      ),
    ];

    if (narrow) {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 12),
          cards[1],
          const SizedBox(height: 12),
          cards[2],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
        const SizedBox(width: 16),
        Expanded(child: cards[2]),
      ],
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String title,
    String subtitle, {
    int? count,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () => _showUnavailableMessage(title),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: _greenSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _green, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 24),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            count.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnavailableMessage(String section) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$section is ready for the next feature update.')),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Log out?',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Are you sure you want to log out of your driver account?',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel', style: TextStyle(color: _muted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
