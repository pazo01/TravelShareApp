import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _userTrips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserTrips();
  }

  Future<void> _fetchUserTrips() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('trips')
          .select('id, destination_address, status, flights(departure_airport, arrival_airport, scheduled_arrival)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _userTrips = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      print('❌ Error fetching trips: $e');
      setState(() => _loading = false);
    }
  }

  // 🗑️ Delete trip
  Future<void> _deleteTrip(String tripId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete trip'),
        content: const Text('Are you sure you want to delete this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('trips').delete().eq('id', tripId);
      setState(() {
        _userTrips.removeWhere((t) => t['id'] == tripId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error deleting trip: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Trips'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _userTrips.isEmpty
              ? const Center(
                  child: Text(
                    'No trips found.\nBook or share a taxi!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _userTrips.length,
                  itemBuilder: (context, index) {
                    final trip = _userTrips[index];
                    return _buildTripCard(trip);
                  },
                ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final flight = trip['flights'] ?? {};
    final dep = flight['departure_airport'] ?? 'Unknown';
    final arr = flight['arrival_airport'] ?? 'Unknown';
    final schedArr = flight['scheduled_arrival'] ?? '';
    final destination = trip['destination_address'] ?? 'Unknown destination';
    final tripStatus = trip['status'] ?? 'Looking for match';

    String fmtDate(String? iso) {
      if (iso == null || iso.isEmpty) return '-';
      final date = DateTime.tryParse(iso);
      if (date == null) return '-';
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📍 Destination on top
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    destination,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteTrip(trip['id'].toString()),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ✈️ Flight route
            Row(
              children: [
                const Icon(Icons.flight_takeoff, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$dep → $arr',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 🕓 Scheduled arrival
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Arrival: ${fmtDate(schedArr)}',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 🚖 Trip status
            Row(
              children: [
                const Icon(Icons.local_taxi, size: 18, color: Colors.amber),
                const SizedBox(width: 6),
                Text(
                  'Trip status: $tripStatus',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
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
