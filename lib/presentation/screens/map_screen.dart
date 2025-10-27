import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mappa')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.map_rounded, size: 64),
            SizedBox(height: 12),
            Text('Placeholder mappa'),
            Text('Qui integreremo Google Maps / OSM.'),
          ],
        ),
      ),
    );
  }
}
