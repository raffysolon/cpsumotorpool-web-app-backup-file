import 'package:flutter/material.dart';

// === My trips page: filterable list of driver trip requests ===
class MyTripsPage extends StatefulWidget {
	const MyTripsPage({super.key});

	@override
	State<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends State<MyTripsPage> {
	// --- Shared dashboard colors: keep this screen aligned with DriverDashboard ---
	static const _green = Color(0xFF0B8F5A);
	static const _greenDark = Color(0xFF087448);
	static const _greenSoft = Color(0xFFE8F7F0);
	static const _ink = Color(0xFF19332A);
	static const _muted = Color(0xFF71827B);
	static const _line = Color(0xFFDCE9E2);
	static const _background = Color(0xFFF7FAF8);

	static const _filters = [
		'All',
		'Pending',
		'Approved',
		'Active',
		'Completed',
		'Denied',
	];

	static const List<Trip> _trips = [
		Trip(
			id: 'TRIP-001',
			route: 'San Carlos to Kabankalan',
			status: 'Active',
			vehicle: '1300',
			departureTime: '08:30 AM',
		),
		Trip(
			id: 'TRIP-002',
			route: 'Bacolod to Silay',
			status: 'Pending',
			vehicle: '1301',
			departureTime: '10:00 AM',
		),
		Trip(
			id: 'TRIP-003',
			route: 'Bacolod to Murcia',
			status: 'Approved',
			vehicle: '1302',
			departureTime: '01:30 PM',
		),
		Trip(
			id: 'TRIP-004',
			route: 'Talisay to Victorias',
			status: 'Completed',
			vehicle: '1303',
			departureTime: '07:00 AM',
		),
		Trip(
			id: 'TRIP-005',
			route: 'Bacolod to La Carlota',
			status: 'Denied',
			vehicle: '1304',
			departureTime: '03:00 PM',
		),
	];

	String _selectedFilter = 'All';

	List<Trip> get _filteredTrips {
		if (_selectedFilter == 'All') return _trips;
		return _trips
				.where((trip) => trip.status == _selectedFilter)
				.toList();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: _background,
			appBar: AppBar(
				backgroundColor: Colors.white,
				foregroundColor: _ink,
				elevation: 0,
				surfaceTintColor: Colors.white,
				title: const Text(
					'My Trips',
					style: TextStyle(fontWeight: FontWeight.w800),
				),
			),
			body: Column(
				children: [
					_buildFilterTabs(),
					Expanded(
						child: _filteredTrips.isEmpty
								? _buildEmptyState()
								: ListView.separated(
										padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
										itemCount: _filteredTrips.length,
										separatorBuilder: (_, __) => const SizedBox(height: 14),
										itemBuilder: (context, index) {
											return _buildTripCard(_filteredTrips[index]);
										},
									),
					),
				],
			),
		);
	}

	// --- Filter tabs: select which trip statuses are visible ---
	Widget _buildFilterTabs() {
		return Container(
			color: Colors.white,
			alignment: Alignment.centerLeft,
			child: SingleChildScrollView(
				scrollDirection: Axis.horizontal,
				padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
				child: Row(
					children: [
						for (final filter in _filters) ...[
							_buildFilterTab(filter),
							const SizedBox(width: 8),
						],
					],
				),
			),
		);
	}

	Widget _buildFilterTab(String filter) {
		final selected = _selectedFilter == filter;
		return ChoiceChip(
			label: Text(filter),
			selected: selected,
			onSelected: (_) => setState(() => _selectedFilter = filter),
			selectedColor: _green,
			backgroundColor: Colors.white,
			side: BorderSide(color: selected ? _green : _line),
			labelStyle: TextStyle(
				color: selected ? Colors.white : _greenDark,
				fontSize: 12,
				fontWeight: FontWeight.w700,
			),
			showCheckmark: false,
			padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
		);
	}

	// --- Trip card: route, status, details, and explicit summary action ---
	Widget _buildTripCard(Trip trip) {
		return InkWell(
			onTap: () => _navigateToTripSummary(trip.id),
			borderRadius: BorderRadius.circular(14),
			child: Container(
				padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
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
								_buildStatusBadge(trip.status),
							],
						),
						const SizedBox(height: 16),
						const Divider(color: _line, height: 1),
						const SizedBox(height: 16),
						LayoutBuilder(
							builder: (context, constraints) {
								final details = [
									_buildTripDetail('VEHICLE', trip.vehicle, expanded: constraints.maxWidth >= 480),
									_buildTripDetail('DEPARTURE', trip.departureTime, expanded: constraints.maxWidth >= 480),
									_buildTripDetail('STATUS', trip.status, expanded: constraints.maxWidth >= 480),
								];
								return constraints.maxWidth < 480
									? Column(
										crossAxisAlignment: CrossAxisAlignment.stretch,
										children: details,
									)
									: Row(children: details);
							},
						),
						const SizedBox(height: 8),
						Align(
							alignment: Alignment.centerRight,
							child: TextButton(
								onPressed: () => _navigateToTripSummary(trip.id),
								style: TextButton.styleFrom(
									foregroundColor: _greenDark,
									padding: const EdgeInsets.symmetric(horizontal: 8),
								),
								child: const Text(
									'View Details',
									style: TextStyle(fontWeight: FontWeight.w800),
								),
							),
						),
					],
				),
			),
		);
	}

	Widget _buildStatusBadge(String status) {
		final denied = status == 'Denied';
		final color = denied ? Colors.red.shade700 : _greenDark;
		final background = denied ? Colors.red.shade50 : _greenSoft;
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
			decoration: BoxDecoration(
				color: background,
				borderRadius: BorderRadius.circular(20),
			),
			child: Text(
				status.toUpperCase(),
				style: TextStyle(
					color: color,
					fontSize: 10,
					fontWeight: FontWeight.w800,
				),
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
							letterSpacing: .6,
						),
					),
					const SizedBox(height: 6),
					Text(
						value,
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
					Icon(Icons.receipt_long_outlined, color: _green, size: 48),
					const SizedBox(height: 12),
					const Text(
						'No trips found',
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
}

// === Trip model: temporary sample data until the backend is connected ===
class Trip {
	const Trip({
		required this.id,
		required this.route,
		required this.status,
		required this.vehicle,
		required this.departureTime,
	});

	final String id;
	final String route;
	final String status;
	final String vehicle;
	final String departureTime;
}
