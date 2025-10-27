import 'package:flutter/material.dart';
import 'trips_screen.dart';
import 'flight_search_screen.dart';
import 'map_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  final pages = const [
    TripsScreen(),
    FlightSearchScreen(),
    MapScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Viaggi'),
          NavigationDestination(icon: Icon(Icons.flight_takeoff_outlined), selectedIcon: Icon(Icons.flight_takeoff), label: 'Voli'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mappa'),
        ],
      ),
    );
  }
}
