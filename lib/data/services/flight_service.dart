import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_keys.dart';



class FlightService {
  final String _baseUrl = 'http://api.aviationstack.com/v1/flights';

  Future<Map<String, dynamic>?> getFlightInfo(String flightNumber) async {
    final url = Uri.parse('$_baseUrl?access_key=${ApiKeys.aviationStack}&flight_iata=$flightNumber');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          return data['data'][0]; // Take the first matching flight
        }
      }
      return null;
    } catch (e) {
      print('Errore fetching flight info: $e');
      return null;
    }
  }
}
