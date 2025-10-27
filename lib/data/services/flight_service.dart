import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FlightService {
  FlightService(this.client);
  final SupabaseClient client;

  static const Duration cacheTtl = Duration(hours: 6);
  String get _apiKey => dotenv.env['AVIATIONSTACK_KEY'] ?? '';

  String _key({String? iata, String? icao, String? number}) {
    if ((iata ?? '').isNotEmpty) return 'iata:${iata!.toUpperCase()}';
    if ((icao ?? '').isNotEmpty) return 'icao:${icao!.toUpperCase()}';
    if ((number ?? '').isNotEmpty) return 'num:$number';
    throw ArgumentError('flight_iata/flight_icao/flight_number richiesto');
  }

  Future<Map<String, dynamic>> getFlight({
    String? flightIata,
    String? flightIcao,
    String? flightNumber,
  }) async {
    final key = _key(iata: flightIata, icao: flightIcao, number: flightNumber);

    final fresh = await _readFresh(key);
    if (fresh != null) return fresh;

    final data = await _fetch(
      flightIata: flightIata,
      flightIcao: flightIcao,
      flightNumber: flightNumber,
    );
    if (data != null) {
      await _insertCache(key, data);
      return data;
    }

    final stale = await _readAny(key);
    if (stale != null) return stale;

    return {'status': 'fallback', 'message': 'Nessun dato disponibile al momento.'};
  }

  Future<Map<String, dynamic>?> _readFresh(String key) async {
    final since = DateTime.now().toUtc().subtract(cacheTtl).toIso8601String();
    final rows = await client
        .from('flight_cache') // usa il tuo nome tabella
        .select('payload,fetched_at')
        .eq('flight_key', key)
        .gte('fetched_at', since)
        .order('fetched_at', ascending: false)
        .limit(1);
    if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first['payload']);
    return null;
  }

  Future<Map<String, dynamic>?> _readAny(String key) async {
    final rows = await client
        .from('flight_cache')
        .select('payload,fetched_at')
        .eq('flight_key', key)
        .order('fetched_at', ascending: false)
        .limit(1);
    if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first['payload']);
    return null;
  }

  Future<void> _insertCache(String key, Map<String, dynamic> data) async {
    final f = Map<String, dynamic>.from(data['flight'] ?? {});
    await client.from('flight_cache').insert({
      'flight_key': key,
      'payload': data,
      // colonne “piatte” (se presenti nella tua tabella)
      'flight_number': f['flight_number'],
      'airline': f['airline_name'],
      'departure_airport': f['dep_airport'],
      'arrival_airport': f['arr_airport'],
      'status': f['status'],
      // 'fetched_at' viene da default now()
    });
  }

  Future<Map<String, dynamic>?> _fetch({
    String? flightIata,
    String? flightIcao,
    String? flightNumber,
  }) async {
    if (_apiKey.isEmpty) return null;
    final uri = Uri.https('api.aviationstack.com', '/v1/flights', {
      'access_key': _apiKey,
      if ((flightIata ?? '').isNotEmpty) 'flight_iata': flightIata,
      if ((flightIcao ?? '').isNotEmpty) 'flight_icao': flightIcao,
      if ((flightNumber ?? '').isNotEmpty) 'flight_number': flightNumber,
      'limit': '1',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) return null;

    final raw = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (raw['data'] as List?) ?? const [];
    if (list.isEmpty) return {'status': 'not_found', 'data': []};

    final x = Map<String, dynamic>.from(list.first as Map);
    return {
      'status': 'ok',
      'flight': {
        'flight_iata': x['flight']?['iata'],
        'flight_icao': x['flight']?['icao'],
        'flight_number': x['flight']?['number'],
        'airline_iata': x['airline']?['iata'],
        'airline_name': x['airline']?['name'],
        'dep_airport': x['departure']?['airport'],
        'dep_iata': x['departure']?['iata'],
        'arr_airport': x['arrival']?['airport'],
        'arr_iata': x['arrival']?['iata'],
        'scheduled_arrival': x['arrival']?['scheduled'],
        'estimated_arrival': x['arrival']?['estimated'],
        'status': x['flight_status'],
      },
      'raw': raw,
    };
  }
}
