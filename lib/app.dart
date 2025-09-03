import 'package:flutter/material.dart';

class TravelShareApp extends StatelessWidget {
  const TravelShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelShare',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'TravelShare - Setup Completato! 🚀',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
