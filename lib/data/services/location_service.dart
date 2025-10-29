// lib/data/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Cache posizione corrente
  Position? _lastKnownPosition;
  DateTime? _lastUpdate;
  final Duration _cacheValidity = const Duration(minutes: 5);

  /// Ottiene la posizione corrente con gestione permessi
  Future<Position?> getCurrentPosition({bool forceRefresh = false}) async {
    try {
      // Usa cache se valida e non forzato refresh
      if (!forceRefresh && 
          _lastKnownPosition != null && 
          _lastUpdate != null &&
          DateTime.now().difference(_lastUpdate!) < _cacheValidity) {
        print('📍 Using cached position');
        return _lastKnownPosition;
      }

      // Controlla se i servizi di localizzazione sono abilitati
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceException(
          'Servizi di localizzazione disabilitati',
          'Attiva il GPS nelle impostazioni del dispositivo',
        );
      }

      // Controlla permessi
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw LocationServiceException(
            'Permesso negato',
            'L\'app necessita del permesso di localizzazione per funzionare',
          );
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw LocationServiceException(
          'Permesso permanentemente negato',
          'Vai nelle impostazioni dell\'app per abilitare la localizzazione',
        );
      }

      // Ottieni posizione con timeout
      print('📍 Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Aggiorna cache
      _lastKnownPosition = position;
      _lastUpdate = DateTime.now();

      print('✅ Position: ${position.latitude}, ${position.longitude}');
      return position;

    } on LocationServiceException {
      rethrow;
    } catch (e) {
      print('❌ Error getting location: $e');
      throw LocationServiceException(
        'Errore localizzazione',
        'Impossibile ottenere la posizione: ${e.toString()}',
      );
    }
  }

  /// Stream per aggiornamenti posizione in tempo reale
  Stream<Position> getPositionStream({
    int distanceFilter = 10,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Calcola distanza tra due punti in metri
  static double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Calcola distanza in formato leggibile
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Controlla se due punti sono entro un raggio
  static bool isWithinRadius(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
    double radiusInMeters,
  ) {
    final distance = calculateDistance(lat1, lng1, lat2, lng2);
    return distance <= radiusInMeters;
  }

  /// Helper per mostrare dialog permessi
  static Future<bool> showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permesso Localizzazione'),
          content: const Text(
            'TravelShare ha bisogno di accedere alla tua posizione per:\n\n'
            '• Trovare la tua posizione attuale\n'
            '• Calcolare percorsi ottimali\n'
            '• Mostrare compagni di viaggio vicini\n\n'
            'I tuoi dati di posizione sono protetti e non vengono mai condivisi senza il tuo consenso.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Rifiuta'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Consenti'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Helper per aprire impostazioni app
  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Helper per aprire impostazioni localizzazione
  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}

/// Eccezione custom per errori di localizzazione
class LocationServiceException implements Exception {
  final String title;
  final String message;

  LocationServiceException(this.title, this.message);

  @override
  String toString() => '$title: $message';
}