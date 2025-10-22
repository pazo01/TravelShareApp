import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/config/api_keys.dart'; // ✅ where your API key is stored

class FlightScreen extends StatefulWidget {
  const FlightScreen({super.key});

  @override
  State<FlightScreen> createState() => _FlightScreenState();
}

class _FlightScreenState extends State<FlightScreen> {
  final TextEditingController _flightNumberController = TextEditingController();
  Map<String, dynamic>? flightData;
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchFlight() async {
    final flightNumber = _flightNumberController.text.trim();
    if (flightNumber.isEmpty) {
      setState(() => errorMessage = 'Please enter a flight number');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      flightData = null;
    });

    final url =
        'http://api.aviationstack.com/v1/flights?access_key=${ApiKeys.aviationStack}&flight_iata=$flightNumber';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          setState(() {
            flightData = data['data'][0];
          });
        } else {
          setState(() {
            errorMessage = 'No flight found for "$flightNumber"';
          });
        }
      } else {
        setState(() {
          errorMessage = 'Error: ${response.reasonPhrase}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch flight data: $e';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flights'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Track Your Flight',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _flightNumberController,
              decoration: InputDecoration(
                labelText: 'Flight Number (e.g. AA100)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.flight_takeoff),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isLoading ? null : fetchFlight,
              ),
            ),
            const SizedBox(height: 24),

            // 🟦 Loading indicator
            if (isLoading)
              const CircularProgressIndicator(),

            // 🟥 Error message
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),

            // 🟩 Flight results
            if (flightData != null) ...[
              const SizedBox(height: 20),
              _buildFlightCard(flightData!, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFlightCard(Map<String, dynamic> flight, ThemeData theme) {
    final airline = flight['airline']?['name'] ?? 'N/A';
    final flightNum = flight['flight']?['iata'] ?? 'N/A';
    final status = flight['flight_status'] ?? 'Unknown';
    final depAirport = flight['departure']?['airport'] ?? 'N/A';
    final arrAirport = flight['arrival']?['airport'] ?? 'N/A';
    final depTime = flight['departure']?['scheduled'] ?? 'N/A';
    final arrTime = flight['arrival']?['scheduled'] ?? 'N/A';

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$airline • $flightNum',
                style: theme.textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.flight_takeoff, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(child: Text('From: $depAirport')),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.flight_land, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text('To: $arrAirport')),
              ],
            ),
            const SizedBox(height: 12),
            Text('Departure: $depTime'),
            Text('Arrival: $arrTime'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.airplanemode_active,
                    color: Colors.orangeAccent),
                const SizedBox(width: 6),
                Text(
                  'Status: ${status.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: status == 'active'
                        ? Colors.green
                        : status == 'landed'
                            ? Colors.grey
                            : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
