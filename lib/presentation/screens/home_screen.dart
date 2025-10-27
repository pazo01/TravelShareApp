import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'flight_screen.dart';
import 'destination_picker_screen.dart'; // 🟩 import the destination picker screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? fullName;
  Position? currentPosition;
  String? locationError;
  bool isLoading = true;
  int _selectedIndex = 0;

  // 🟩 new variables to store destination info
  String? _selectedAddress;
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _loadCurrentLocation();
  }

  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select('full_name, email')
          .eq('id', user.id)
          .single();

      setState(() {
        fullName = profile['full_name'] as String?;
        isLoading = false;
      });
    } catch (e) {
      print('Errore nel recupero profilo: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadCurrentLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      setState(() => currentPosition = pos);
    } else {
      setState(() => locationError = 'Impossibile recuperare la posizione');
    }
  }

  // 🟩 1️⃣ Function to open the destination picker
  Future<void> _openDestinationPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DestinationPickerScreen()),
    );

    if (result != null) {
      setState(() {
        _selectedAddress = result['address'];
        _selectedLat = result['lat'];
        _selectedLng = result['lng'];
      });

      // 🟩 show a confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Destinazione selezionata: $_selectedAddress')),
      );
    }
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FlightScreen()),
      );
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Benvenuto in TravelShare'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),

      // ✅ Main body
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_pin_circle, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  Text(
                    fullName ?? 'Nome non disponibile',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  if (currentPosition != null)
                    Text(
                      'Lat: ${currentPosition!.latitude.toStringAsFixed(5)}, '
                      'Lng: ${currentPosition!.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    )
                  else if (locationError != null)
                    Text(
                      locationError!,
                      style: const TextStyle(color: Colors.red),
                    )
                  else
                    const CircularProgressIndicator(),

                  const SizedBox(height: 30),

                  // 🟩 2️⃣ New button for destination picker
                  ElevatedButton.icon(
                    onPressed: _openDestinationPicker,
                    icon: const Icon(Icons.map),
                    label: const Text('Scegli Destinazione'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  // 🟩 3️⃣ Show selected destination below
                  if (_selectedAddress != null) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Destinazione selezionata:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(_selectedAddress!),
                  ],
                ],
              ),
      ),

      // ✅ Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flight_takeoff),
            label: 'Flights',
          ),
        ],
      ),
    );
  }
}
