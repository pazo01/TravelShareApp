import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/api_keys.dart';
import 'destination_picker_screen.dart';
import '../../data/services/matching_service.dart';
import '../../data/services/group_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _flightController = TextEditingController();
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? _flightData;
  bool _isLoading = false;
  String? _errorMessage;

  String? selectedAddress;
  double? selectedLat;
  double? selectedLng;

  // 🛫 Fetch flight data from AviationStack
  Future<void> _fetchFlight() async {
    final flightNumber = _flightController.text.trim();
    if (flightNumber.isEmpty) {
      setState(() => _errorMessage = 'Please enter a flight code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _flightData = null;
    });

    final url = Uri.parse(
      'http://api.aviationstack.com/v1/flights?access_key=${ApiKeys.aviationStack}&flight_iata=$flightNumber',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          setState(() => _flightData = data['data'][0]);
        } else {
          setState(() => _errorMessage = 'No flight found for "$flightNumber"');
        }
      } else {
        setState(() => _errorMessage = 'Error: ${response.reasonPhrase}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 📍 Open destination picker
  Future<void> _openDestinationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DestinationPickerScreen()),
    );

    if (result != null) {
      setState(() {
        selectedAddress = result['address'];
        selectedLat = (result['lat'] as num?)?.toDouble();
        selectedLng = (result['lng'] as num?)?.toDouble();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected destination: $selectedAddress')),
      );
    }
  }

  // 🧱 Build UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Taxi Share'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Enter your flight and destination',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 30),

            // ✈️ Flight input + search button (same row)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _flightController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _fetchFlight(),
                    decoration: InputDecoration(
                      labelText: 'Flight Code (e.g. AZ123)',
                      prefixIcon: const Icon(Icons.flight_takeoff),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _fetchFlight,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Icon(Icons.search, size: 24),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: CircularProgressIndicator()),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),

            if (_flightData != null) _buildFlightSummary(_flightData!),

            const SizedBox(height: 20),

            // 📍 Destination picker
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text('Select Destination'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _openDestinationPicker,
            ),

            if (selectedAddress != null) ...[
              const SizedBox(height: 12),
              Text(
                'Destination: $selectedAddress',
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 30),

            // 🟩 FIND BUTTON — creates the trip and triggers matching
            ElevatedButton(
              onPressed: (selectedAddress != null && _flightData != null)
                  ? _createTripAndMatch
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Find'),
            ),
            
          
          
          ],
        ),
      ),
    );
  }

  // ✈️ Flight summary card
  Widget _buildFlightSummary(Map<String, dynamic> flight) {
    final depAirport = flight['departure']?['airport'] ?? 'Unknown';
    final depTime = flight['departure']?['scheduled'] ?? '';
    final arrAirport = flight['arrival']?['airport'] ?? 'Unknown';
    final arrTime = flight['arrival']?['scheduled'] ?? '';

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.flight_takeoff, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    depAirport,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(depTime.split('T').first),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.flight_land, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    arrAirport,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(arrTime.split('T').first),
              ],
            ),
          ],
        ),
      ),
    );
  }




  // 🧩 Create trip + run matching logic
  Future<void> _createTripAndMatch() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }

    try {
      final flightNum = _flightData!['flight']?['iata'] ?? 'Unknown';
      final airline = _flightData!['airline']?['name'] ?? 'Unknown';
      final dep = _flightData!['departure']?['airport'] ?? 'Unknown';
      final arr = _flightData!['arrival']?['airport'] ?? 'Unknown';
      final schedArr = _flightData!['arrival']?['scheduled'];
      final actualArr = _flightData!['arrival']?['actual'];
      final status = _flightData!['flight_status'] ?? 'unknown';

      // 🟦 Step 1: Upsert flight
      final flightResponse = await supabase
          .from('flights')
          .upsert({
            'flight_number': flightNum,
            'airline': airline,
            'departure_airport': dep,
            'arrival_airport': arr,
            'scheduled_arrival': schedArr,
            'actual_arrival': actualArr,
            'status': status,
          })
          .select('id')
          .single();

      final flightId = flightResponse['id'];

      // 🟩 Step 2: Create trip
      final tripInsert = await supabase
          .from('trips')
          .insert({
            'user_id': user.id,
            'flight_id': flightId,
            'destination_address': selectedAddress,
            'destination_lat': selectedLat,
            'destination_lng': selectedLng,
            'status': 'looking_for_match',
          })
          .select('id')
          .single();

      final tripId = tripInsert['id'];

      // 🟧 Step 3: Run matching function
final scheduledArrival = DateTime.parse(
  _flightData!['arrival']?['scheduled'] ?? DateTime.now().toIso8601String(),
);

final matchResponse = await MatchingService.findCompatibleTrips(
  userId: user.id,
  arrivalAirport: arr,
  scheduledArrival: scheduledArrival,
);




if (matchResponse.isNotEmpty) {
  // 🟢 Update matched trips
  print('✅ Found ${matchResponse.length} matches');
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('🎉 Match found! Trip updated.')),
  );
  if (matchResponse.isNotEmpty) {
  // Add the current user’s trip too, so they both get grouped
  final currentTrip = {
    'trip_id': tripId, // from your inserted trip
    'user_id': user.id,
  };

  final allTrips = [...matchResponse, currentTrip];

  await GroupService.createOrJoinGroup(
  matchedTrips: allTrips,
  );

}

} else {
  print('ℹ️ No matches yet.');
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('No matches found yet. Looking for match...')),
  );
}





      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
