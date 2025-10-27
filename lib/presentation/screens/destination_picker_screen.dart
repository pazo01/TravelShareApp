import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
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
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;

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

  // 🟩 Funzione per ottenere suggerimenti da Photon API
  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    //prova per far funzionare le suggestions
    print("🔎 Fetching suggestions for: $query");



    setState(() => _isLoading = true);
    final url = Uri.parse('https://photon.komoot.io/api/?q=$query&lang=en');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;
        setState(() {
          _suggestions = features
              .map((f) => {
                    'name': f['properties']['name'] ?? '',
                    'city': f['properties']['city'] ?? '',
                    'country': f['properties']['country'] ?? '',
                    'lat': f['geometry']['coordinates'][1],
                    'lon': f['geometry']['coordinates'][0],
                  })
              .where((item) => item['name'] != '')
              .toList();
        });
      }
    } catch (e) {
      print("Errore caricamento suggerimenti: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final point = LatLng(suggestion['lat'], suggestion['lon']);
    _mapController.move(point, 15);
    setState(() {
      _selectedPoint = point;
      _selectedAddress =
          "${suggestion['name']}, ${suggestion['city'] ?? ''}, ${suggestion['country'] ?? ''}";
      _suggestions = [];
      _searchController.text = _selectedAddress!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scegli la destinazione")),
      body: Stack(
        children: [
          // MAPPA
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
            right: 20,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _fetchSuggestions, // 🟩 aggiorna suggerimenti mentre scrivi
                    decoration: const InputDecoration(
                      hintText: "Cerca indirizzo...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                // LISTA SUGGERIMENTI
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final s = _suggestions[index];
                        return ListTile(
                          title: Text(s['name']),
                          subtitle: Text("${s['city'] ?? ''}, ${s['country'] ?? ''}"),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),
                  ),
              ],
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
