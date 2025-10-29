// lib/data/services/flight_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_keys.dart';

class FlightService {
  static final FlightService _instance = FlightService._internal();
  factory FlightService() => _instance;
  FlightService._internal();

  final String _baseUrl = 'http://api.aviationstack.com/v1/flights';
  
  // Cache per ridurre chiamate API (30 minuti)
  final Map<String, CachedFlight> _cache = {};
  final Duration _cacheValidity = const Duration(minutes: 30);

  /// Recupera informazioni volo con cache intelligente
  Future<Map<String, dynamic>?> getFlightInfo(String flightNumber, {DateTime? date}) async {
    // Genera chiave cache
    final dateStr = date?.toIso8601String().split('T')[0] ?? DateTime.now().toIso8601String().split('T')[0];
    final cacheKey = '${flightNumber}_$dateStr';
    
    // Controlla cache
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheValidity) {
        print('✅ Flight $flightNumber from cache');
        return cached.data;
      }
    }

    // Chiamata API
    final params = {
      'access_key': ApiKeys.aviationStack,
      'flight_iata': flightNumber.toUpperCase(),
    };
    
    if (date != null) {
      params['flight_date'] = dateStr;
    }

    final url = Uri.parse(_baseUrl).replace(queryParameters: params);

    try {
      print('🔍 Fetching flight: $flightNumber for date: $dateStr');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Timeout nella ricerca del volo'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          final flightData = data['data'][0];
          
          // Salva in cache
          _cache[cacheKey] = CachedFlight(
            data: flightData,
            timestamp: DateTime.now(),
          );
          
          return flightData;
        }
        throw Exception('Volo non trovato');
      } else if (response.statusCode == 401) {
        throw Exception('API Key non valida. Verifica la tua chiave AviationStack');
      } else {
        throw Exception('Errore API: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Errore FlightService: $e');
      rethrow;
    }
  }

  /// Parsing helper per estrarre info utili
  static FlightInfo? parseFlightData(Map<String, dynamic> data) {
    try {
      return FlightInfo(
        flightNumber: data['flight']?['iata'] ?? '',
        airline: data['airline']?['name'] ?? 'Sconosciuta',
        status: data['flight_status'] ?? 'scheduled',
        departureAirport: data['departure']?['airport'] ?? '',
        departureIata: data['departure']?['iata'] ?? '',
        arrivalAirport: data['arrival']?['airport'] ?? '',
        arrivalIata: data['arrival']?['iata'] ?? '',
        scheduledArrival: DateTime.tryParse(data['arrival']?['scheduled'] ?? ''),
        actualArrival: DateTime.tryParse(data['arrival']?['actual'] ?? ''),
        terminal: data['arrival']?['terminal'],
        gate: data['arrival']?['gate'],
      );
    } catch (e) {
      print('Errore parsing flight data: $e');
      return null;
    }
  }

  /// Pulisce la cache
  void clearCache() {
    _cache.clear();
  }
}

// Modello per cache
class CachedFlight {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  CachedFlight({required this.data, required this.timestamp});
}

// Modello per info volo strutturate
class FlightInfo {
  final String flightNumber;
  final String airline;
  final String status;
  final String departureAirport;
  final String departureIata;
  final String arrivalAirport;
  final String arrivalIata;
  final DateTime? scheduledArrival;
  final DateTime? actualArrival;
  final String? terminal;
  final String? gate;

  FlightInfo({
    required this.flightNumber,
    required this.airline,
    required this.status,
    required this.departureAirport,
    required this.departureIata,
    required this.arrivalAirport,
    required this.arrivalIata,
    this.scheduledArrival,
    this.actualArrival,
    this.terminal,
    this.gate,
  });

  bool get isDelayed {
    if (actualArrival == null || scheduledArrival == null) return false;
    return actualArrival!.difference(scheduledArrival!).inMinutes > 15;
  }

  String get statusDisplay {
    switch (status) {
      case 'scheduled': return '📅 Programmato';
      case 'active': return '✈️ In volo';
      case 'landed': return '✅ Atterrato';
      case 'cancelled': return '❌ Cancellato';
      case 'diverted': return '↩️ Deviato';
      default: return status;
    }
  }
}