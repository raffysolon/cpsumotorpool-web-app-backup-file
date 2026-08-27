import 'package:latlong2/latlong.dart';

// === Active vehicle model: data shown by the fleet map ===
class ActiveVehicle {
  const ActiveVehicle({
    required this.plate,
    required this.driver,
    required this.destination,
    required this.position,
  });

  final String plate;
  final String driver;
  final String destination;
  final LatLng position;
}

// === Map data: default center and sample active vehicles ===
/// Sample active fleet around Bacolod / Negros Occidental.
const bacolodCenter = LatLng(10.6713, 122.9511);

const activeVehicles = [
  ActiveVehicle(
    plate: 'SJA 4421',
    driver: 'Ramon Dela Cruz',
    destination: 'San Carlos',
    position: LatLng(10.6765, 122.9508),
  ),
  ActiveVehicle(
    plate: 'ABC 1234',
    driver: 'Maria Santos',
    destination: 'Silay',
    position: LatLng(10.7286, 122.9744),
  ),
  ActiveVehicle(
    plate: 'XYZ 5678',
    driver: 'Juan Reyes',
    destination: 'Kabankalan',
    position: LatLng(10.6312, 122.9681),
  ),
];
