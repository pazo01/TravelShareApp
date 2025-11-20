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
  final FocusNode _searchFocusNode = FocusNode();

  LatLng? _selectedPoint;
  String? _selectedAddress;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;

  // Per future implementazioni (Giorno 7)
  double _flexibleRadius = 1000; // metri
  bool _showRadius = false; // Per ora nascosto

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    // Focus listener per gestire apertura/chiusura suggerimenti
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty) {
        setState(() => _showSuggestions = true);
      }
    });
  }

  /// Ottiene posizione corrente all'apertura
  /// Centra la mappa ma lascia il campo ricerca vuoto
  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null && mounted) {
        final point = LatLng(position.latitude, position.longitude);
        if (mounted) {
          _mapController.move(point, 15);
        }
      }
    } on LocationServiceException catch (e) {
      print('⚠️ Location error (handled): ${e.title} - ${e.message}');
      if (mounted) {
        _mapController.move(LatLng(41.9028, 12.4964), 13);
      }
    } catch (e) {
      print('❌ Unexpected location error: $e');
      if (mounted) {
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
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    final url = Uri.parse(
      'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&lang=it&limit=8'
    );

    try {
      print('🔍 Searching for: $query');
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout ricerca'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;

        print('📍 Found ${features.length} results');

        if (mounted) {
          setState(() {
            _suggestions = features
                .map((f) {
                  final props = f['properties'];
                  final display = _formatSuggestionDisplay(props);

                  // Debug: mostra cosa stiamo creando
                  print('  - $display');

                  return {
                    'name': props['name'] ?? '',
                    'street': props['street'] ?? '',
                    'city': props['city'] ?? '',
                    'state': props['state'] ?? '',
                    'country': props['country'] ?? '',
                    'lat': f['geometry']['coordinates'][1],
                    'lon': f['geometry']['coordinates'][0],
                    'display': display,
                  };
                })
                .where((item) => (item['display'] as String).isNotEmpty)
                .take(8)
                .toList();

            print('✅ Showing ${_suggestions.length} suggestions');
          });
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Errore ricerca: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Formatta suggerimento per display (più intelligente)
  String _formatSuggestionDisplay(Map<String, dynamic> props) {
    final parts = <String>[];

    // Priorità: name > street > city
    if (props['name'] != null && props['name'].toString().isNotEmpty) {
      parts.add(props['name']);
    } else if (props['street'] != null && props['street'].toString().isNotEmpty) {
      parts.add(props['street']);
    }

    if (props['city'] != null && props['city'].toString().isNotEmpty) {
      parts.add(props['city']);
    }

    if (props['state'] != null && props['state'].toString().isNotEmpty) {
      parts.add(props['state']);
    }

    if (props['country'] != null && props['country'].toString().isNotEmpty) {
      parts.add(props['country']);
    }

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
      _showSuggestions = false;
      _searchController.text = _selectedAddress!;
    });

    // Chiudi la tastiera
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          "Scegli destinazione",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
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
                  _showSuggestions = false;
                });
                _getAddressFromLatLng(point);
                _searchFocusNode.unfocus();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.travelshare',
                maxZoom: 19,
              ),

              if (_selectedPoint != null) ...[
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

          // SEARCH BAR & SUGGESTIONS (DESIGN MODERNO)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search field con design moderno
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (value) {
                        _fetchSuggestions(value);
                      },
                      onSubmitted: (value) {
                        if (_suggestions.isNotEmpty) {
                          _selectSuggestion(_suggestions.first);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "Dove vuoi andare?",
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                        suffixIcon: _isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              )
                            : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _suggestions = [];
                                        _showSuggestions = false;
                                      });
                                    },
                                  )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),

                  // Suggestions list (DESIGN MODERNO)
                  if (_showSuggestions && _suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _suggestions.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 60,
                          endIndent: 16,
                          color: Colors.grey[200],
                        ),
                        itemBuilder: (context, index) {
                          final s = _suggestions[index];
                          final isFirst = index == 0;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _selectSuggestion(s),
                              borderRadius: BorderRadius.vertical(
                                top: isFirst ? const Radius.circular(16) : Radius.zero,
                                bottom: index == _suggestions.length - 1
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.location_on,
                                        color: theme.primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s['name']?.isNotEmpty == true
                                                ? s['name']
                                                : s['street']?.isNotEmpty == true
                                                    ? s['street']
                                                    : s['city'] ?? 'Luogo',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${s['city'] ?? ''} ${s['country'] ?? ''}".trim(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey[400],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Current location button (DESIGN MODERNO)
          Positioned(
            bottom: 140,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _goToCurrentLocation,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      Icons.my_location,
                      color: theme.primaryColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Selected address display (DESIGN MODERNO)
          if (_selectedAddress != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedAddress!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Confirm button (DESIGN MODERNO)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _selectedPoint == null ? null : _confirmSelection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: _selectedPoint == null ? 0 : 8,
                shadowColor: theme.primaryColor.withOpacity(0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Conferma destinazione",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
      'radius': _flexibleRadius,
    });
  }

  /// Mostra dialog informativo
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Come funziona',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const SingleChildScrollView(
          child: Text(
            '🔍 Digita il tuo indirizzo di destinazione\n\n'
            '📍 Vedrai suggerimenti in tempo reale\n\n'
            '👆 Tocca un suggerimento o la mappa\n\n'
            '📱 Usa il pulsante GPS per la posizione attuale\n\n'
            '✅ Conferma la destinazione scelta',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'HO CAPITO',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
    _searchFocusNode.dispose();
    super.dispose();
  }
}
