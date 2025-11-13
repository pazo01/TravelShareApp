// lib/data/services/trip_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class TripService {
  static final TripService _instance = TripService._internal();
  factory TripService() => _instance;
  TripService._internal();

  final SupabaseClient _client = SupabaseConfig.client;

  /// Crea un nuovo viaggio nel database
  Future<Map<String, dynamic>?> createTrip({
    required String flightNumber,
    required String airline,
    required String departureAirport,
    required String arrivalAirport,
    required DateTime? scheduledArrival,
    required String destinationAddress,
    required double destinationLat,
    required double destinationLng,
    String? status,
    Map<String, dynamic>? additionalFlightData,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utente non autenticato');
      }

      // 1. Prima crea o recupera il volo
      final flightData = await _createOrGetFlight(
        flightNumber: flightNumber,
        airline: airline,
        departureAirport: departureAirport,
        arrivalAirport: arrivalAirport,
        scheduledArrival: scheduledArrival,
        status: status ?? 'scheduled',
      );

      if (flightData == null) {
        throw Exception('Impossibile creare il volo');
      }

      final flightId = flightData['id'];

      // 2. Crea il viaggio
      final tripData = await _client.from('trips').insert({
        'user_id': userId,
        'flight_id': flightId,
        'destination_address': destinationAddress,
        'destination_lat': destinationLat,
        'destination_lng': destinationLng,
        'status': 'looking_for_match',
        'flexible_zone_radius': 1000, // Default 1km
        'max_detour_time': 15, // Default 15 minuti
      }).select().single();

      print('✅ Viaggio creato con successo: ${tripData['id']}');
      return tripData;

    } catch (e) {
      print('❌ Errore creazione viaggio: $e');
      rethrow;
    }
  }

  /// Crea o recupera un volo esistente usando UPSERT (atomico)
  Future<Map<String, dynamic>?> _createOrGetFlight({
    required String flightNumber,
    required String airline,
    required String departureAirport,
    required String arrivalAirport,
    required DateTime? scheduledArrival,
    required String status,
  }) async {
    try {
      // Usa UPSERT: inserisce se non esiste, aggiorna se esiste
      // Questo evita race condition e l'errore "multiple rows"
      final flightData = await _client.from('flights').upsert({
        'flight_number': flightNumber,
        'airline': airline,
        'departure_airport': departureAirport,
        'arrival_airport': arrivalAirport,
        'scheduled_arrival': scheduledArrival?.toIso8601String(),
        'status': status,
      }).select('id').single();

      print('✈️ Volo gestito (upsert): ${flightData['id']}');
      return flightData;

    } catch (e) {
      print('❌ Errore gestione volo: $e');
      rethrow;
    }
  }

  /// Recupera tutti i viaggi dell'utente corrente - VERSIONE SEMPLIFICATA
  Future<List<Map<String, dynamic>>> getUserTrips() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utente non autenticato');
      }

      // Query semplificata per evitare ricorsione
      final trips = await _client
          .from('trips')
          .select('''
            id,
            user_id,
            flight_id,
            destination_address,
            destination_lat,
            destination_lng,
            flexible_zone_radius,
            max_detour_time,
            status,
            notes,
            created_at,
            updated_at,
            flights:flight_id (
              id,
              flight_number,
              airline,
              departure_airport,
              arrival_airport,
              scheduled_arrival,
              actual_arrival,
              status
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('📚 Viaggi recuperati: ${trips.length}');
      return List<Map<String, dynamic>>.from(trips);

    } catch (e) {
      print('❌ Errore recupero viaggi: $e');
      return [];
    }
  }

  /// Cancella un viaggio
  Future<void> deleteTrip(String tripId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utente non autenticato');
      }

      await _client
          .from('trips')
          .delete()
          .eq('id', tripId)
          .eq('user_id', userId);

      print('🗑️ Viaggio eliminato: $tripId');

    } catch (e) {
      print('❌ Errore eliminazione viaggio: $e');
      rethrow;
    }
  }

  /// Aggiorna lo stato di un viaggio
  Future<void> updateTripStatus(String tripId, String newStatus) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utente non autenticato');
      }

      await _client
          .from('trips')
          .update({'status': newStatus})
          .eq('id', tripId)
          .eq('user_id', userId);

      print('🔄 Stato viaggio aggiornato: $newStatus');

    } catch (e) {
      print('❌ Errore aggiornamento stato: $e');
      rethrow;
    }
  }

  /// Recupera un singolo viaggio con dettagli base
  Future<Map<String, dynamic>?> getTripDetails(String tripId) async {
    try {
      final trip = await _client
          .from('trips')
          .select('''
            *,
            flights:flight_id (*)
          ''')
          .eq('id', tripId)
          .maybeSingle();

      return trip;

    } catch (e) {
      print('❌ Errore recupero dettagli viaggio: $e');
      return null;
    }
  }

  /// Stream per ricevere aggiornamenti in tempo reale sui viaggi
  Stream<List<Map<String, dynamic>>> getUserTripsStream() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return _client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  /// Conta i membri del gruppo per un viaggio (query separata)
  /// Usa una query semplice senza count per compatibilità
  Future<int> getGroupMembersCount(String tripId) async {
    try {
      final members = await _client
          .from('group_members')
          .select('id')
          .eq('trip_id', tripId);

      return members.length;
    } catch (e) {
      print('❌ Errore conteggio membri: $e');
      return 0;
    }
  }
  
  /// Controlla se ci sono membri del gruppo per un viaggio
  Future<bool> hasGroupMembers(String tripId) async {
    try {
      final members = await _client
          .from('group_members')
          .select('id')
          .eq('trip_id', tripId)
          .limit(1);

      return members.isNotEmpty;
    } catch (e) {
      print('❌ Errore verifica membri: $e');
      return false;
    }
  }
}