import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({super.key});

  @override
  State<DestinationPickerScreen> createState() => _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen> {
  final MapController _mapController = MapController();

  LatLng? _selectedPoint;
  String? _selectedAddress;
  final TextEditingController _searchController = TextEditingController();

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _selectedAddress = "${p.street ?? ''}, ${p.locality ?? ''}";
        });
      }
    } catch (e) {
      print("Errore nel recupero indirizzo: $e");
    }
  }

  // 🟩 Cerca indirizzo scritto dall’utente
  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final point = LatLng(loc.latitude, loc.longitude);

        _mapController.move(point, 15); // zoom sulla destinazione
        setState(() {
          _selectedPoint = point;
          _selectedAddress = query;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indirizzo non trovato')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nella ricerca: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scegli la destinazione")),
      body: Stack(
        children: [
          // 🗺️ MAPPA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(41.9028, 12.4964),
              initialZoom: 13,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPoint = point;
                });
                _getAddressFromLatLng(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.travelshare',
              ),
              if (_selectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40,
                      height: 40,
                      point: _selectedPoint!,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  ],
                ),
            ],
          ),

          // 🔍 CAMPO DI RICERCA
          Positioned(
            top: 20,
            left: 20,
            right: 70,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Cerca indirizzo...",
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchAddress,
                  ),
                ),
              ),
            ),
          ),

          // ✅ Bottone conferma
          Positioned(
            bottom: 30,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              onPressed: _selectedPoint == null
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'lat': _selectedPoint!.latitude,
                        'lng': _selectedPoint!.longitude,
                        'address': _selectedAddress ?? 'Sconosciuto',
                      });
                    },
              icon: const Icon(Icons.check),
              label: const Text("Conferma destinazione"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
