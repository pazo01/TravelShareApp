import 'package:flutter/material.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demoTrips = [
      ('Roma ✈️ NYC', '18–25 Set 2025 · 7 notti'),
      ('Madeira', '22–29 Set 2025 · 7 notti'),
      ('Tokyo', 'Gen–Mar 2026 · bozza'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('I miei viaggi')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: demoTrips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final (title, subtitle) = demoTrips[i];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.flight_class_rounded)),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {},
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Nuovo viaggio'),
      ),
    );
  }
}
