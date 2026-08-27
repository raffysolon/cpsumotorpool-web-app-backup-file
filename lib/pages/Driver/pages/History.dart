import 'package:flutter/material.dart';

// === Trip history page: completed driver trip tickets ===
class HistoryPage extends StatefulWidget {
	const HistoryPage({super.key});

	@override
	State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
	// --- Shared dashboard colors: use the same driver dashboard palette ---
	static const _green = Color(0xFF0B8F5A);
	static const _greenDark = Color(0xFF087448);
	static const _greenSoft = Color(0xFFE8F7F0);
	static const _ink = Color(0xFF19332A);
	static const _muted = Color(0xFF71827B);
	static const _line = Color(0xFFDCE9E2);
	static const _background = Color(0xFFF7FAF8);

	static const _dateRanges = ['All time', 'This month', 'Last 3 months'];
	static const List<Trip> _trips = [
		Trip(
			id: 'TRIP-101',
			route: 'San Carlos to Kabankalan',
			date: 'August 18, 2026',
			distance: '142 km',
			duration: '3h 20m',
			status: 'Completed',
		),
		Trip(
			id: 'TRIP-102',
			route: 'Bacolod to Silay',
			date: 'August 12, 2026',
			distance: '48 km',
			duration: '1h 15m',
			status: 'Completed',
		),
		Trip(
			id: 'TRIP-103',
			route: 'Bacolod to Murcia',
			date: 'July 29, 2026',
			distance: '76 km',
			duration: '2h 05m',
			status: 'Completed',
		),
	];

	String _selectedDateRange = 'All time';

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
					'Trip History',
					style: TextStyle(fontWeight: FontWeight.w800),
				),
			),
			body: Column(
				children: [
					_buildDateRangeFilter(),
					Expanded(
						child: _trips.isEmpty
								? _buildEmptyState()
								: ListView.separated(
										padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
										itemCount: _trips.length,
										separatorBuilder: (_, __) => const SizedBox(height: 14),
										itemBuilder: (context, index) => _buildTripCard(_trips[index]),
									),
					),
				],
			),
		);
	}

	// --- Date filter: UI is ready for date-range filtering logic ---
	Widget _buildDateRangeFilter() {
		return Container(
			color: Colors.white,
			alignment: Alignment.centerLeft,
			child: SingleChildScrollView(
				scrollDirection: Axis.horizontal,
				padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
				child: Row(
					children: [
						for (final dateRange in _dateRanges) ...[
							ChoiceChip(
								label: Text(dateRange),
								selected: _selectedDateRange == dateRange,
								onSelected: (_) => setState(() {
									_selectedDateRange = dateRange;
								}),
								selectedColor: _green,
								backgroundColor: Colors.white,
								side: BorderSide(
									color: _selectedDateRange == dateRange ? _green : _line,
								),
								labelStyle: TextStyle(
									color: _selectedDateRange == dateRange
											? Colors.white
											: _greenDark,
									fontSize: 12,
									fontWeight: FontWeight.w700,
								),
								showCheckmark: false,
							),
							const SizedBox(width: 8),
						],
					],
				),
			),
		);
	}

	// --- Completed trip card: route, summary details, and ticket actions ---
	Widget _buildTripCard(Trip trip) {
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
							_buildCompletedBadge(trip.status),
						],
					),
					const SizedBox(height: 16),
					const Divider(color: _line, height: 1),
					const SizedBox(height: 16),
					LayoutBuilder(
						builder: (context, constraints) {
							final details = [
								_buildTripDetail('DATE', trip.date, expanded: constraints.maxWidth >= 480),
								_buildTripDetail('DISTANCE', trip.distance, expanded: constraints.maxWidth >= 480),
								_buildTripDetail('DURATION', trip.duration, expanded: constraints.maxWidth >= 480),
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
					Row(
						mainAxisAlignment: MainAxisAlignment.end,
						children: [
							TextButton.icon(
								onPressed: () => _viewTripTicket(trip.id),
								icon: const Icon(Icons.visibility_outlined, size: 17),
								label: const Text('View'),
								style: TextButton.styleFrom(
									foregroundColor: _greenDark,
									visualDensity: VisualDensity.compact,
								),
							),
							const SizedBox(width: 4),
							TextButton.icon(
								onPressed: () => _printTripTicket(trip.id),
								icon: const Icon(Icons.print_outlined, size: 17),
								label: const Text('Print'),
								style: TextButton.styleFrom(
									foregroundColor: _greenDark,
									visualDensity: VisualDensity.compact,
								),
							),
						],
					),
				],
			),
		);
	}

	Widget _buildCompletedBadge(String status) {
		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
			decoration: BoxDecoration(
				color: _greenSoft,
				borderRadius: BorderRadius.circular(20),
			),
			child: Text(
				status.toUpperCase(),
				style: const TextStyle(
					color: _greenDark,
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
					Icon(Icons.history_rounded, color: _green, size: 48),
					const SizedBox(height: 12),
					const Text(
						'No completed trips yet',
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

	void _viewTripTicket(String tripId) {
		// TODO: Open the PDF preview for tripId.
	}

	void _printTripTicket(String tripId) {
		// TODO: Download or print the trip ticket PDF for tripId.
	}
}

// === Trip model: temporary completed-trip data until the backend is connected ===
class Trip {
	const Trip({
		required this.id,
		required this.route,
		required this.date,
		required this.distance,
		required this.duration,
		required this.status,
	});

	final String id;
	final String route;
	final String date;
	final String distance;
	final String duration;
	final String status;
}
