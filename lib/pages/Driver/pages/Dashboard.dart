import '../../../services/notification_updates.dart';
import '../../../widgets/app_notification.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cpsumotorpooladmin/services/notification_service.dart';
import 'package:cpsumotorpooladmin/services/notification_sound_service.dart';
import 'package:cpsumotorpooladmin/services/trip_service.dart';
import 'package:cpsumotorpooladmin/pages/services/auth_service.dart';
import 'package:cpsumotorpooladmin/utils/driver_trip_lifecycle.dart';
import 'package:cpsumotorpooladmin/widgets/app_shell.dart';
import 'package:cpsumotorpooladmin/widgets/driver_trip_details.dart';
import 'package:cpsumotorpooladmin/widgets/notification_dialog.dart';
import 'package:cpsumotorpooladmin/widgets/skeleton_widgets_web.dart';

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
  final _notificationUpdates = NotificationUpdates();
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
      final trips = await TripService.getMyTrips();
      Map<String, dynamic>? nextActiveTrip;
      Map<String, dynamic>? nextScheduledTrip;
      for (final trip in trips.whereType<Map>()) {
        final candidate = Map<String, dynamic>.from(trip);
        if (DriverTripLifecycle.hasActuallyStarted(candidate)) {
          nextActiveTrip = candidate;
          break;
        }
        if (DriverTripLifecycle.isScheduled(candidate) &&
            nextScheduledTrip == null) {
          nextScheduledTrip = candidate;
        }
      }
      nextActiveTrip ??= nextScheduledTrip;

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
    } catch (error) {
      debugPrint('Dashboard._loadActiveTrip error: $error');
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
      final rawTrips = await TripService.getMyTrips();

      // Count trips for "My Trips" - everything except active and completed
      final visibleMyTrips = rawTrips.where((trip) {
        final storedStatus = (trip['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final effectiveStatus = (trip['effective_status'] ?? storedStatus)
            .toString()
            .trim()
            .toLowerCase();
        return effectiveStatus != 'active' && effectiveStatus != 'completed';
      }).toList();

      // Count completed trips for history
      final completedTrips = rawTrips.where((trip) {
        final storedStatus = (trip['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final effectiveStatus = (trip['effective_status'] ?? storedStatus)
            .toString()
            .trim()
            .toLowerCase();
        return effectiveStatus == 'completed';
      }).toList();

      if (!mounted) return;

      final nextMyTripsCount = visibleMyTrips.length;
      final nextScheduledTripsCount = rawTrips.whereType<Map>().where((trip) {
        final storedStatus = (trip['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        final effectiveStatus = (trip['effective_status'] ?? storedStatus)
            .toString()
            .trim()
            .toLowerCase();
        return effectiveStatus == 'scheduled';
      }).length;
      final nextHistoryTripsCount = completedTrips.length;

      if (!background ||
          _myTripsCount != nextMyTripsCount ||
          _scheduledTripsCount != nextScheduledTripsCount ||
          _historyTripsCount != nextHistoryTripsCount) {
        setState(() {
          _myTripsCount = nextMyTripsCount;
          _scheduledTripsCount = nextScheduledTripsCount;
          _historyTripsCount = nextHistoryTripsCount;

          _isLoadingTripCounts = false;
        });
      }
    } catch (error) {
      debugPrint('Dashboard._loadTripCounts error: $error');
      if (background) return;
      if (!mounted) return;
      setState(() {
        _myTripsCount = 0;
        _scheduledTripsCount = 0;
        _historyTripsCount = 0;
        _isLoadingTripCounts = false;
      });
    }
  }

  Future<void> _loadNotifications({bool background = false}) async {
    try {
      final notificationsResult = await NotificationService.getNotifications();

      final count = notificationsResult
          .where((n) => n['is_read'] != true)
          .length;
      final notifications = notificationsResult
          .map<Map<String, dynamic>>(
            (item) => {
              ...item,
              'id': item['id'] ?? 0,
              'message': item['message'] ?? 'Notification',
              'created_at': item['created_at'] ?? '',
              'event_key': item['event_key'],
              'priority': item['priority'] ?? 'normal',
              'is_read': item['is_read'] == true,
            },
          )
          .toList();

      try {
        final accountScope = await AuthService.getNotificationAccountScope();
        if (accountScope != null) {
          final message = _notificationUpdates.observe(
            accountScope,
            notifications,
          );
          if (message != null) AppNotification.showMessage(message);
          await NotificationSoundService.instance.observeNotifications(
            accountScope: accountScope,
            notifications: notifications,
          );
        }
      } catch (error) {
        debugPrint('Driver notification sound processing failed: $error');
      }

      if (!mounted) return;

      {
        setState(() {
          _notificationCount = count;
          _notifications = notifications;
        });
      }
    } catch (error) {
      debugPrint('Dashboard._loadNotifications error: $error');
      if (background) return;
      if (!mounted) return;
      setState(() {
        // Keep the last successful inbox while a request fails.
      });
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return NotificationDialog(
          notifications: _notifications,
          loadNotifications: NotificationService.getNotifications,
          onDelete: (id) async {
            await NotificationService.deleteNotification(id);
            if (mounted) await _loadNotifications();
          },
          onAcknowledge: (id) async {
            await NotificationService.markAsRead(id);
            if (mounted) await _loadNotifications();
          },
        );
      },
    );
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
    if (!DriverTripLifecycle.hasActuallyStarted(trip)) return 'Start Trip';
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
    if ('${returnMovement?['status'] ?? ''}' == 'active') {
      return 'End Return Trip';
    }
    if ('${outbound?['status'] ?? ''}' == 'active') {
      return 'End Trip';
    }
    if ('${outbound?['status'] ?? ''}' == 'completed') {
      return 'Start Return Trip';
    }
    return 'End Trip';
  }

  Widget _buildCurrentActiveTripCard() {
    if (_isLoadingActiveTrip) {
      return SkeletonWidgetsWeb.activeTripCard();
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
    final tripStarted = DriverTripLifecycle.hasActuallyStarted(trip);
    final canStart = DriverTripLifecycle.canStart(trip);
    final startDisabledReason = DriverTripLifecycle.startDisabledReason(trip);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tripStarted ? 'Active Trip' : 'Upcoming Trip',
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
                  color: tripStarted ? _greenSoft : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tripStarted ? 'ACTIVE' : 'SCHEDULED',
                  style: TextStyle(
                    color: tripStarted ? _greenDark : Colors.orange.shade900,
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
          DriverTripDetails(
            vehicle: vehicleLabel,
            departure: _formatDeparture(
              trip['scheduled_departure']?.toString(),
            ),
            status: tripStarted ? 'In Progress' : 'Scheduled',
          ),
          const SizedBox(height: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: tripStarted || canStart ? _showEndTripDialog : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.grey.shade700,
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
              if (!tripStarted && !canStart) ...[
                const SizedBox(height: 8),
                Text(
                  startDisabledReason,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ],
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
        _buildBrandMark(size: narrow ? 34 : 42),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _line),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset('assets/images/cpsu logo.png', fit: BoxFit.contain),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to end trip: $error')));
    }
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
      await AuthService.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }
}
