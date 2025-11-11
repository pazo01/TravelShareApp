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

    // PRIMO TENTATIVO: con data (se fornita)
    try {
      return await _fetchFlight(flightNumber, dateStr, includeDate: date != null);
    } catch (e) {
      print('⚠️ Tentativo con data fallito: $e');
      
      // SECONDO TENTATIVO: senza data (piano gratuito potrebbe non supportarla)
      if (date != null) {
        print('🔄 Riprovo senza parametro data...');
        try {
          return await _fetchFlight(flightNumber, dateStr, includeDate: false);
        } catch (e2) {
          print('❌ Anche senza data ha fallito: $e2');
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Metodo interno per effettuare la chiamata API
  Future<Map<String, dynamic>> _fetchFlight(
    String flightNumber,
    String dateStr,
    {required bool includeDate}
  ) async {
    final params = <String, String>{
      'access_key': ApiKeys.aviationStack,
      'flight_iata': flightNumber.toUpperCase(),
    };

    // Aggiungi data solo se richiesto
    if (includeDate) {
      params['flight_date'] = dateStr;
    }

    // IMPORTANTE: Costruisci URL HTTP manualmente per piano gratuito (non supporta HTTPS)
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final urlString = 'http://api.aviationstack.com/v1/flights?$queryString';
    
    print('🔍 Fetching flight: $flightNumber${includeDate ? ' for date: $dateStr' : ' (no date)'}');
    print('🔗 URL: $urlString');
    
    final response = await http.get(Uri.parse(urlString)).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('Timeout nella ricerca del volo'),
    );

    print('📡 Response status: ${response.statusCode}');
    print('📄 Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Controlla se ci sono errori nella risposta
      if (data['error'] != null) {
        final errorMsg = data['error']['message'] ?? data['error']['info'] ?? 'Unknown error';
        final errorCode = data['error']['code'];
        throw Exception('API Error ($errorCode): $errorMsg');
      }
      
      if (data['data'] != null && data['data'].isNotEmpty) {
        final flightData = data['data'][0];
        
        // Salva in cache
        final cacheKey = '${flightNumber}_$dateStr';
        _cache[cacheKey] = CachedFlight(
          data: flightData,
          timestamp: DateTime.now(),
        );
        
        return flightData;
      }
      throw Exception('Volo non trovato nei risultati');
    } else if (response.statusCode == 401) {
      throw Exception('API Key non valida. Verifica la tua chiave AviationStack');
    } else if (response.statusCode == 403) {
      // Proviamo a decodificare il body per vedere il messaggio esatto
      try {
        final errorData = json.decode(response.body);
        final errorMsg = errorData['error']?['info'] ?? errorData['error']?['message'] ?? 'Accesso negato';
        throw Exception('403 - $errorMsg');
      } catch (_) {
        throw Exception('403 - Accesso negato. Il piano gratuito supporta solo HTTP. Possibili cause:\n'
            '1) API Key non attiva o scaduta\n'
            '2) Limite mensile raggiunto (1000 chiamate/mese)\n'
            '3) Parametri non supportati dal piano gratuito');
      }
    } else if (response.statusCode == 429) {
      throw Exception('Limite di richieste superato (max 1000/mese per piano gratuito)');
    } else {
      throw Exception('Errore API: ${response.statusCode} - ${response.body}');
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