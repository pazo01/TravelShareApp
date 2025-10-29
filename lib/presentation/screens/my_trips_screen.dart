import 'package:flutter/material.dart';

class MyTripsScreen extends StatelessWidget {
  const MyTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('I miei viaggi'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.luggage, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nessun viaggio attivo',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'I tuoi viaggi appariranno qui',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}