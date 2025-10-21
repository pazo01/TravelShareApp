import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    final name = user?.userMetadata?['name'] ?? 'Nome non disponibile';
    final surname = user?.userMetadata?['surname'] ?? '';

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
              // After signing out, go back to the AuthGate / WelcomeScreen
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_pin_circle, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            Text(
              '$name $surname',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
