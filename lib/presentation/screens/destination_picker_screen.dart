// lib/presentation/screens/destination_picker_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../../data/services/location_service.dart';

class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({super.key});

  @override
  State<DestinationPickerScreen> createState() => _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _selectedPoint;
  String? _selectedAddress;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  
  // Per future implementazioni (Giorno 7)
  double _flexibleRadius = 1000; // metri
  bool _showRadius = false; // Per ora nascosto

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  /// Ottiene posizione corrente all'apertura
  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null && mounted) {
        final point = LatLng(position.latitude, position.longitude);
        if (mounted) {
          _mapController.move(point, 15);
          setState(() {
            _selectedPoint = point;
          });
          _getAddressFromLatLng(point);
        }
      }
    } on LocationServiceException catch (e) {
      // Errore gestito: mostra solo un messaggio senza bloccare l'app
      print('⚠️ Location error (handled): ${e.title} - ${e.message}');
      if (mounted) {
        // Centra su Roma se non riesce
        _mapController.move(LatLng(41.9028, 12.4964), 13);
      }
    } catch (e) {
      print('❌ Unexpected location error: $e');
      if (mounted) {
        // Se non riesce, centra su Roma
        _mapController.move(LatLng(41.9028, 12.4964), 13);
      }
    }
  }

  /// Converte coordinate in indirizzo
  Future<void> _getAddressFromLatLng(LatLng position) async {
    if (!mounted) return;
    
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          _selectedAddress = _formatAddress(p);
          _searchController.text = _selectedAddress!;
        });
      }
    } catch (e) {
      print("Errore geocoding inverso: $e");
      if (mounted) {
        setState(() {
          _selectedAddress = "Lat: ${position.latitude.toStringAsFixed(4)}, "
                            "Lng: ${position.longitude.toStringAsFixed(4)}";
        });
      }
    }
  }

  /// Formatta l'indirizzo in modo leggibile
  String _formatAddress(Placemark p) {
    final parts = <String>[];
    
    if (p.street != null && p.street!.isNotEmpty) {
      parts.add(p.street!);
    }
    if (p.locality != null && p.locality!.isNotEmpty) {
      parts.add(p.locality!);
    }
    if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
      parts.add(p.administrativeArea!);
    }
    if (p.country != null && p.country!.isNotEmpty) {
      parts.add(p.country!);
    }
    
    return parts.isNotEmpty ? parts.join(', ') : 'Posizione selezionata';
  }

  /// Ricerca suggerimenti da Photon/Nominatim
  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty || query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);
    
    // Usa Photon (più veloce) o Nominatim come fallback
    final url = Uri.parse(
      'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&lang=it&limit=5'
    );

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout ricerca'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;
        
        if (mounted) {
          setState(() {
            _suggestions = features
                .map((f) => {
                  'name': f['properties']['name'] ?? '',
                  'city': f['properties']['city'] ?? '',
                  'state': f['properties']['state'] ?? '',
                  'country': f['properties']['country'] ?? '',
                  'lat': f['geometry']['coordinates'][1],
                  'lon': f['geometry']['coordinates'][0],
                  'display': _formatSuggestion(f['properties']),
                })
                .where((item) => item['name'] != '')
                .take(5)
                .toList();
          });
        }
      }
    } catch (e) {
      print("Errore ricerca: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Formatta suggerimento per display
  String _formatSuggestion(Map<String, dynamic> props) {
    final parts = <String>[];
    
    if (props['name'] != null) parts.add(props['name']);
    if (props['city'] != null) parts.add(props['city']);
    if (props['state'] != null) parts.add(props['state']);
    if (props['country'] != null) parts.add(props['country']);
    
    return parts.join(', ');
  }

  /// Seleziona un suggerimento
  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final point = LatLng(suggestion['lat'], suggestion['lon']);
    _mapController.move(point, 16);
    setState(() {
      _selectedPoint = point;
      _selectedAddress = suggestion['display'];
      _suggestions = [];
      _searchController.text = _selectedAddress!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scegli la destinazione"),
        actions: [
          // Info button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // MAPPA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(41.9028, 12.4964),
              initialZoom: 13,
              minZoom: 3,
              maxZoom: 19,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPoint = point;
                  _suggestions = [];
                });
                _getAddressFromLatLng(point);
              },
            ),
            children: [
              // Tile Layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.travelshare',
                maxZoom: 19,
              ),
              
              // Marker Layer
              if (_selectedPoint != null) ...[
                // Raggio flessibile (per implementazione futura)
                if (_showRadius)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _selectedPoint!,
                        radius: _flexibleRadius,
                        useRadiusInMeter: true,
                        color: Colors.blue.withOpacity(0.1),
                        borderColor: Colors.blue.withOpacity(0.5),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                
                // Marker principale
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 50,
                      height: 50,
                      point: _selectedPoint!,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                        shadows: [
                          Shadow(
                            blurRadius: 12,
                            color: Colors.black26,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          // SEARCH BAR & SUGGESTIONS
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Search field
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _fetchSuggestions(value);
                    },
                    decoration: InputDecoration(
                      hintText: "Cerca indirizzo, hotel, zona...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _suggestions = [];
                                    });
                                  },
                                )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // Suggestions list
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final s = _suggestions[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.grey),
                          title: Text(
                            s['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            "${s['city'] ?? ''} ${s['country'] ?? ''}".trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Current location button
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // Confirm button
          Positioned(
            bottom: 30,
            left: 50,
            right: 50,
            child: ElevatedButton.icon(
              onPressed: _selectedPoint == null ? null : _confirmSelection,
              icon: const Icon(Icons.check),
              label: const Text("Conferma destinazione"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
            ),
          ),

          // Selected address display
          if (_selectedAddress != null)
            Positioned(
              bottom: 90,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedAddress!,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Va alla posizione corrente
  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoading = true);
    
    try {
      final position = await _locationService.getCurrentPosition(forceRefresh: true);
      if (position != null && mounted) {
        final point = LatLng(position.latitude, position.longitude);
        _mapController.move(point, 16);
        setState(() {
          _selectedPoint = point;
        });
        _getAddressFromLatLng(point);
      }
    } catch (e) {
      if (e is LocationServiceException) {
        _showError(e.title, e.message);
      } else {
        _showError('Errore', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Conferma selezione
  void _confirmSelection() {
    if (_selectedPoint == null) return;
    
    Navigator.pop(context, {
      'lat': _selectedPoint!.latitude,
      'lng': _selectedPoint!.longitude,
      'address': _selectedAddress ?? 'Posizione selezionata',
      'radius': _flexibleRadius, // Per uso futuro
    });
  }

  /// Mostra dialog informativo
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Come funziona'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Cerca un indirizzo usando la barra di ricerca\n\n'
            '2. Oppure tocca direttamente sulla mappa\n\n'
            '3. Usa il pulsante GPS per la tua posizione attuale\n\n'
            '4. Conferma la destinazione selezionata\n\n'
            'Prossimamente: potrai impostare un raggio flessibile '
            'per aumentare le possibilità di trovare compagni di viaggio!',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Mostra errore
  void _showError(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (title.contains('permesso'))
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                LocationService.openAppSettings();
              },
              child: const Text('Apri Impostazioni'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}