import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travelshare/data/services/flight_service.dart';

class FlightTestScreen extends StatefulWidget {
  const FlightTestScreen({super.key});
  @override
  State<FlightTestScreen> createState() => _FlightTestScreenState();
}

class _FlightTestScreenState extends State<FlightTestScreen> {
  final _controller = TextEditingController();
  String _result = '';

  Future<void> _search() async {
    final svc = FlightService(Supabase.instance.client);
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _result = 'Caricamento...');
    final data = await svc.getFlight(flightIata: code);
    setState(() => _result = data.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Voli Supabase')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: 'Codice volo (es. AZ201)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _search, child: const Text('Cerca volo')),
            const SizedBox(height: 20),
            Expanded(child: SingleChildScrollView(child: Text(_result))),
          ],
        ),
      ),
    );
  }
}
