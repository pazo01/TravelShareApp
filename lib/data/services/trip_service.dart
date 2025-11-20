// lib/data/services/trip_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';

class TripService {
  static final TripService _instance = TripService._internal();
  factory TripService() => _instance;
  TripService._internal();

  final SupabaseClient _client = SupabaseConfig.client;

  /// ---------------------------------------------------------------------------
  /// CREA UN NUOVO VIAGGIO
  /// ---------------------------------------------------------------------------
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
    Map<String, dynamic>? additionalFlightData,   // ✅ RESTORED
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Utente non autenticato');
      }

      // 1️⃣ CREA O RECUPERA IL VOLO
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

      // 2️⃣ CREA IL VIAGGIO
      final tripData = await _client
          .from('trips')
          .insert({
            'user_id': userId,
            'flight_id': flightData['id'],
            'destination_address': destinationAddress,
            'destination_lat': destinationLat,
            'destination_lng': destinationLng,
            'status': 'looking_for_match',
            'flexible_zone_radius': 1000,
            'max_detour_time': 15,
            'notes': additionalFlightData != null
                ? additionalFlightData.toString()
                : null,
          })
          .select()
          .single();

      print('✅ Viaggio creato con successo: ${tripData['id']}');
      return tripData;

    } catch (e) {
      print('❌ Errore creazione viaggio: $e');
      rethrow;
    }
  }

  /// ---------------------------------------------------------------------------
  /// CREA O RECUPERA IL VOLO (UPSERT)
  /// ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _createOrGetFlight({
    required String flightNumber,
    required String airline,
    required String departureAirport,
    required String arrivalAirport,
    required DateTime? scheduledArrival,
    required String status,
  }) async {
    try {
      final flightData = await _client
          .from('flights')
          .upsert({
            'flight_number': flightNumber,
            'airline': airline,
            'departure_airport': departureAirport,
            'arrival_airport': arrivalAirport,
            'scheduled_arrival': scheduledArrival?.toIso8601String(),
            'status': status,
          })
          .select('id')
          .single();

      print('✈️ Volo gestito (upsert): ${flightData['id']}');
      return flightData;

    } catch (e) {
      print('❌ Errore gestione volo: $e');
      rethrow;
    }
  }

  /// ---------------------------------------------------------------------------
  /// RECUPERA I VIAGGI DELL'UTENTE (NO JOIN CON GROUP_MEMBERS)
  /// ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getUserTrips() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception("Utente non autenticato");

      final trips = await _client
          .from('trips')
          .select('''
            *,
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

  /// ---------------------------------------------------------------------------
  /// RECUPERA group_id DAL trip_id  (PER CHAT)
  /// ---------------------------------------------------------------------------
    Future<String?> getGroupIdForTrip(String tripId) async {
    print("🟦 DEBUG → getGroupIdForTrip() called");
    print("🟦 tripId received: $tripId");

    try {
      final result = await _client
          .from('group_members')
          .select('group_id')
          .eq('trip_id', tripId)
          .maybeSingle();

      print("🟩 DEBUG → Supabase result: $result");

      if (result == null) {
        print("🟥 DEBUG → No group_members row found for this trip");
        return null;
      }

      print("🟢 DEBUG → Found group_id: ${result['group_id']}");
      return result['group_id'].toString();

    } catch (e) {
      print('❌ DEBUG ERROR getGroupIdForTrip: $e');
      return null;
    }
  }


    /// ---------------------------------------------------------------------------
    /// CANCELLA UN VIAGGIO
    /// ---------------------------------------------------------------------------
    Future<void> deleteTrip(String tripId) async {
      try {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) throw Exception('Utente non autenticato');

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

  /// ---------------------------------------------------------------------------
  /// AGGIORNA STATO VIAGGIO
  /// ---------------------------------------------------------------------------
  Future<void> updateTripStatus(String tripId, String newStatus) async {
    try {
      await _client
          .from('trips')
          .update({'status': newStatus})
          .eq('id', tripId);

      print('🔄 Stato viaggio aggiornato: $newStatus');

    } catch (e) {
      print('❌ Errore aggiornamento stato: $e');
      rethrow;
    }
  }

  /// ---------------------------------------------------------------------------
  /// DETTAGLI DI UN VIAGGIO
  /// ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> getTripDetails(String tripId) async {
    try {
      return await _client
          .from('trips')
          .select('*, flights:flight_id (*)')
          .eq('id', tripId)
          .maybeSingle();

    } catch (e) {
      print('❌ Errore recupero dettagli viaggio: $e');
      return null;
    }
  }
}
