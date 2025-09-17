import 'package:flutter/material.dart';
import 'presentation/screens/auth_test_screen.dart';

class TravelShareApp extends StatelessWidget {
  const TravelShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelShare',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const AuthTestScreen(),
    );
  }
}
