import 'package:flutter/material.dart';

// === Scheduled trips page: approved trips that have not started ===
class ScheduleTripPage extends StatelessWidget {
	const ScheduleTripPage({super.key});

	// --- Shared dashboard colors: use the exact DriverDashboard palette ---
	static const _green = Color(0xFF0B8F5A);
	static const _greenDark = Color(0xFF087448);
	static const _greenSoft = Color(0xFFE8F7F0);
	static const _ink = Color(0xFF19332A);
	static const _muted = Color(0xFF71827B);
	static const _line = Color(0xFFDCE9E2);
	static const _background = Color(0xFFF7FAF8);

	static final List<Trip> _sampleTrips = [
		Trip(
			id: 'TRIP-201',
			route: 'Bacolod to Silay',
			status: 'Approved',
			vehicle: '1301',
			departureTime: 'August 22, 2026 at 06:00 PM',
			expectedArrival: '07:15 PM',
			scheduledDeparture: DateTime(2026, 8, 22, 18),
		),
		Trip(
			id: 'TRIP-202',
			route: 'San Carlos to Kabankalan',
			status: 'Approved',
			vehicle: '1300',
			departureTime: 'August 24, 2026 at 08:30 AM',
			expectedArrival: '11:50 AM',
			scheduledDeparture: DateTime(2026, 8, 24, 8, 30),
		),
		Trip(
			id: 'TRIP-203',
			route: 'Bacolod to Murcia',
			status: 'Approved',
			vehicle: '1302',
			departureTime: 'September 2, 2026 at 01:30 PM',
			expectedArrival: '03:35 PM',
			scheduledDeparture: DateTime(2026, 9, 2, 13, 30),
		),
	];

	List<Trip> get _upcomingTrips {
		final now = DateTime.now();
		return _sampleTrips
				.where(
					(trip) =>
							trip.status == 'Approved' &&
							trip.scheduledDeparture.isAfter(now),
				)
				.toList()
			..sort(
				(first, second) => first.scheduledDeparture.compareTo(
					second.scheduledDeparture,
				),
			);
	}

	@override
	Widget build(BuildContext context) {
		final trips = _upcomingTrips;
		return Scaffold(
			backgroundColor: _background,
			appBar: AppBar(
				backgroundColor: Colors.white,
				foregroundColor: _ink,
				elevation: 0,
				surfaceTintColor: Colors.white,
				title: const Text(
					'Scheduled Trips',
					style: TextStyle(fontWeight: FontWeight.w800),
				),
			),
			body: trips.isEmpty
					? _buildEmptyState()
					: ListView.separated(
							padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
							itemCount: trips.length,
							separatorBuilder: (_, __) => const SizedBox(height: 14),
							itemBuilder: (context, index) => _buildTripCard(trips[index]),
						),
		);
	}

	// --- Scheduled trip card: route, timing, status, and ticket actions ---
	Widget _buildTripCard(Trip trip) {
		final departingSoon = trip.scheduledDeparture.isBefore(
			DateTime.now().add(const Duration(hours: 24)),
		);

		return Container(
			padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(14),
				border: Border.all(color: _line),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Expanded(
								child: Text(
									trip.route,
									style: const TextStyle(
										color: _ink,
										fontSize: 18,
										fontWeight: FontWeight.w800,
									),
								),
							),
							const SizedBox(width: 12),
							_buildStatusBadge(),
						],
					),
					if (departingSoon) ...[
						const SizedBox(height: 10),
						_buildDepartingSoonLabel(),
					],
					const SizedBox(height: 16),
					const Divider(color: _line, height: 1),
					const SizedBox(height: 16),
					LayoutBuilder(
						builder: (context, constraints) {
							final details = [
								_buildTripDetail('VEHICLE', trip.vehicle, expanded: constraints.maxWidth >= 560),
								_buildTripDetail('SCHEDULED DEPARTURE', trip.departureTime, expanded: constraints.maxWidth >= 560),
								_buildTripDetail('EXPECTED ARRIVAL', trip.expectedArrival, expanded: constraints.maxWidth >= 560),
							];
							return constraints.maxWidth < 560
								? Column(
									crossAxisAlignment: CrossAxisAlignment.stretch,
									children: details,
								)
								: Row(children: details);
						},
					),
					const SizedBox(height: 10),
					Wrap(
						alignment: WrapAlignment.end,
						spacing: 8,
						runSpacing: 8,
						children: [
							OutlinedButton.icon(
								onPressed: () => _navigateToTripSummary(trip.id),
								icon: const Icon(Icons.visibility_outlined, size: 16),
								label: const Text('View Details'),
								style: _actionButtonStyle(),
							),
							OutlinedButton.icon(
								onPressed: () => _printTripTicket(trip.id),
								icon: const Icon(Icons.print_outlined, size: 16),
								label: const Text('Print Trip Ticket'),
								style: _actionButtonStyle(),
							),
						],
					),
				],
			),
		);
	}

	ButtonStyle _actionButtonStyle() {
		return OutlinedButton.styleFrom(
			foregroundColor: _greenDark,
			side: const BorderSide(color: _green),
			visualDensity: VisualDensity.compact,
			padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
			textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
		);
	}

	Widget _buildStatusBadge() {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
			decoration: BoxDecoration(
				color: _greenSoft,
				borderRadius: BorderRadius.circular(20),
			),
			child: const Text(
				'APPROVED',
				style: TextStyle(
					color: _greenDark,
					fontSize: 10,
					fontWeight: FontWeight.w800,
				),
			),
		);
	}

	Widget _buildDepartingSoonLabel() {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
			decoration: BoxDecoration(
				color: _greenSoft,
				borderRadius: BorderRadius.circular(6),
			),
			child: const Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(Icons.schedule_outlined, color: _greenDark, size: 14),
					SizedBox(width: 5),
					Text(
						'Departing soon',
						style: TextStyle(
							color: _greenDark,
							fontSize: 11,
							fontWeight: FontWeight.w700,
						),
					),
				],
			),
		);
	}

	Widget _buildTripDetail(
		String label,
		String value, {
		bool expanded = true,
	}) {
		final detail = Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						label,
						style: const TextStyle(
							color: _muted,
							fontSize: 9,
							fontWeight: FontWeight.w700,
							letterSpacing: .4,
						),
					),
					const SizedBox(height: 6),
					Text(
						value,
						maxLines: 2,
						overflow: TextOverflow.ellipsis,
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

	Widget _buildEmptyState() {
		return Center(
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(Icons.schedule_outlined, color: _green, size: 48),
					const SizedBox(height: 12),
					const Text(
						'No upcoming trips scheduled',
						style: TextStyle(
							color: _ink,
							fontSize: 16,
							fontWeight: FontWeight.w700,
						),
					),
				],
			),
		);
	}

	void _navigateToTripSummary(String tripId) {
		// TODO: Navigate to the trip summary page for tripId.
	}

	void _printTripTicket(String tripId) {
		// TODO: Download or print the trip ticket PDF for tripId.
	}
}

// === Trip model: scheduled trip fields used by this placeholder screen ===
class Trip {
	const Trip({
		required this.id,
		required this.route,
		required this.status,
		required this.vehicle,
		required this.departureTime,
		required this.expectedArrival,
		required this.scheduledDeparture,
	});

	final String id;
	final String route;
	final String status;
	final String vehicle;
	final String departureTime;
	final String expectedArrival;
	final DateTime scheduledDeparture;
}
