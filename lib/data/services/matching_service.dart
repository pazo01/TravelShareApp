import 'package:supabase_flutter/supabase_flutter.dart';

class MatchingService {
  static final _supabase = Supabase.instance.client;

  /// 🧩 Finds compatible trips based on:
  /// - Arrival airport (same airport)
  /// - Scheduled arrival time (±30 min)
  /// - Destination location (within 5km radius)
  static Future<List<Map<String, dynamic>>> findCompatibleTrips({
    required String userId,
    required String arrivalAirport,
    required DateTime scheduledArrival,
    required double destinationLat,
    required double destinationLng,
    double maxDistanceKm = 5.0,
  }) async {
    try {
      print('🚀 Calling find_compatible_trips...');
      print('📤 Params → user_id: $userId');
      print('📤 Params → airport: $arrivalAirport');
      print('📤 Params → scheduled_arrival: $scheduledArrival');
      print('📤 Params → destination: ($destinationLat, $destinationLng)');
      print('📤 Params → max_distance: ${maxDistanceKm}km');

      final response = await _supabase.rpc(
        'find_compatible_trips',
        params: {
          'p_user_id': userId,
          'p_arrival_airport': arrivalAirport,
          'p_scheduled_arrival': scheduledArrival.toIso8601String(),
          'p_destination_lat': destinationLat,
          'p_destination_lng': destinationLng,
          'p_max_distance_km': maxDistanceKm,
        },
      );

      print('📦 RPC raw response: $response');

      if (response == null) {
        print('⚠️ RPC returned null.');
        return [];
      }

      if (response is List) {
        final results = List<Map<String, dynamic>>.from(response);
        print('✅ RPC returned ${results.length} matches');
        for (final match in results) {
          print('➡️ Match: $match');
        }
        return results;
      }

      print('⚠️ Unexpected response type: ${response.runtimeType}');
      return [];
    } catch (e) {
      print('❌ Error calling find_compatible_trips: $e');
      return [];
    }
  }
}
