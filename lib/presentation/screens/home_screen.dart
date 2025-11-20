// lib/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/auth_service.dart';
import 'auth_screen.dart';
import 'flight_screen.dart';
import 'my_trips_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _selectedIndex;

  final List<Widget> _pages = [
    const FlightScreen(),      // Nuovo Viaggio (ora con matching integrato!)
    const MyTripsScreen(),     // I miei viaggi
    const MessagesScreen(),        // Chat
    const ProfileScreen(),     // Profilo
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.flight_takeoff),
      selectedIcon: Icon(Icons.flight_takeoff, size: 28),
      label: 'Nuovo Viaggio',
    ),
    NavigationDestination(
      icon: Icon(Icons.luggage_outlined),
      selectedIcon: Icon(Icons.luggage),
      label: 'I miei viaggi',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: 'Messaggi',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profilo',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _checkAuthentication();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _selectedIndex = widget.initialIndex;
      });
    }
  }

  void _checkAuthentication() {
    if (!AuthService.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we should navigate to a specific tab
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is int && arguments != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _selectedIndex = arguments);
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: _destinations,
        elevation: 8,
        shadowColor: Colors.black26,
      ),
    );
  }
}
