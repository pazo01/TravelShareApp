// lib/presentation/screens/my_trips_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/trip_service.dart';
import 'home_screen.dart';
import 'chat_screen.dart'; // ✅ IMPORT CHAT SCREEN

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  final _tripService = TripService();
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoading = true);

    try {
      final trips = await _tripService.getUserTrips();
      print('📱 Viaggi caricati nella UI: ${trips.length}');
      // Load group info for each trip
      for (var trip in trips) {
        final group = await _tripService.getGroupForTrip(trip['id']);
        trip['group_data'] = group; // attach to the trip
      }

      setState(() {
        _trips = trips;
        _isLoading = false;
      });

    } catch (e) {
      print('❌ Errore caricamento viaggi: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel caricamento dei viaggi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('I miei viaggi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrips,
            tooltip: 'Aggiorna',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadTrips,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    itemBuilder: (context, index) {
                      return _buildTripCard(_trips[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const HomeScreen(initialIndex: 0),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Viaggio'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.luggage, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nessun viaggio attivo',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'I tuoi viaggi appariranno qui',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeScreen(initialIndex: 0),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Crea il tuo primo viaggio'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final flight = trip['flights'] as Map<String, dynamic>?;
    final scheduledArrival = flight?['scheduled_arrival'] != null
        ? DateTime.tryParse(flight!['scheduled_arrival'].toString())
        : null;

    final statusInfo = _getTripStatusInfo(trip);


    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTripDetails(trip),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------------------------------------------------
              // HEADER ROW + CHAT ICON  💬🔥
              // ---------------------------------------------------------
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.flight_takeoff, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${flight?['airline'] ?? 'Compagnia'} ${flight?['flight_number'] ?? 'N/A'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${flight?['departure_airport'] ?? 'N/A'} → ${flight?['arrival_airport'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ---------- 💬 CHAT BUTTON ----------
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                    tooltip: "Chat gruppo",
                    onPressed: () async {
                      final tripId = trip['id'].toString();

                      print("🟦 Chat icon tapped for tripId = $tripId");

                      // 1️⃣ Fetch group ID from Supabase
                      final groupId = await TripService().getGroupIdForTrip(tripId);

                      print("🟩 Supabase groupId result = $groupId");

                      // 2️⃣ If no group exists → show message
                      if (groupId == null) {
                        print("🟥 No group found for this trip in group_members table");
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Nessun gruppo disponibile per questo viaggio"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      print("🟢 Opening ChatScreen with groupId = $groupId");

                      // 3️⃣ Navigate to ChatScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            groupId: groupId,
                            groupName: "Chat Viaggio",
                          ),
                        ),
                      );
                    },
                  ),


                  // Existing popup menu
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleTripAction(value, trip),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20),
                            SizedBox(width: 8),
                            Text('Dettagli'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Elimina', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Destination row
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trip['destination_address']?.toString() ?? 'Destinazione non specificata',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Date + status
              Row(
                children: [
                  if (scheduledArrival != null) ...[
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(scheduledArrival),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusInfo['icon'] as IconData, size: 16),
                        const SizedBox(width: 4),
                        Text(statusInfo['label'] as String),
                      ],
                    ),
                    backgroundColor: statusInfo['color'] as Color,
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getTripStatusInfo(Map<String, dynamic> trip) {
  final group = trip['group_data'] as Map<String, dynamic>?;

  final int current = group?['current_members'] ?? 0;
  final int max = group?['max_members'] ?? 4;

  String matchIndicator = current > 0 ? " • $current/$max" : "";

  final status = trip['status'] ?? 'looking_for_match';

  switch (status) {
    case 'looking_for_match':
      return {
        'label': 'Cerco compagni$matchIndicator',
        'icon': Icons.search,
        'color': Colors.orange.shade100,
      };
    case 'matched':
      return {
        'label': 'Gruppo trovato$matchIndicator',
        'icon': Icons.group,
        'color': Colors.green.shade100,
      };
    default:
      return {
        'label': 'In attesa$matchIndicator',
        'icon': Icons.hourglass_empty,
        'color': Colors.grey.shade100,
      };
  }
}



  void _showTripDetails(Map<String, dynamic> trip) {
    final flight = trip['flights'] as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Dettagli Viaggio',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                _buildDetailSection(
                  icon: Icons.flight,
                  title: 'Volo',
                  content:
                      '${flight?['airline'] ?? ''} ${flight?['flight_number'] ?? 'N/A'}',
                  subtitle:
                      '${flight?['departure_airport'] ?? 'N/A'} → ${flight?['arrival_airport'] ?? 'N/A'}',
                ),

                _buildDetailSection(
                  icon: Icons.location_on,
                  title: 'Destinazione',
                  content: trip['destination_address']?.toString() ??
                      'Non specificata',
                ),

                _buildDetailSection(
                  icon: Icons.radar,
                  title: 'Raggio flessibile',
                  content:
                      '${trip['flexible_zone_radius'] ?? 1000} metri',
                  subtitle:
                      'Max deviazione: ${trip['max_detour_time'] ?? 15} minuti',
                ),

                _buildDetailSection(
                  icon: Icons.info_outline,
                  title: 'Stato',
                  content: _getTripStatusInfo(trip)['label'] as String,
                ),


                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDelete(trip);
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Elimina',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final groupId = trip['group_members']?['group_id'];
                          if (groupId == null) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                groupId: groupId.toString(),
                                groupName: "Chat Viaggio",
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat Gruppo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required String content,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleTripAction(String action, Map<String, dynamic> trip) {
    switch (action) {
      case 'details':
        _showTripDetails(trip);
        break;
      case 'delete':
        _confirmDelete(trip);
        break;
    }
  }

  void _confirmDelete(Map<String, dynamic> trip) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Viaggio'),
        content: const Text('Sei sicuro di voler eliminare questo viaggio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTrip(trip['id'].toString());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrip(String tripId) async {
    try {
      await _tripService.deleteTrip(tripId);
      await _loadTrips();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viaggio eliminato'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore eliminazione: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
