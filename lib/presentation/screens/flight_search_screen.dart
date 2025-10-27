import 'package:flutter/material.dart';

class FlightSearchScreen extends StatefulWidget {
  const FlightSearchScreen({super.key});

  @override
  State<FlightSearchScreen> createState() => _FlightSearchScreenState();
}

class _FlightSearchScreenState extends State<FlightSearchScreen> {
  final fromCtrl = TextEditingController(text: 'FCO');
  final toCtrl   = TextEditingController(text: 'JFK');
  DateTime? date = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    fromCtrl.dispose();
    toCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = date;
    return Scaffold(
      appBar: AppBar(title: const Text('Cerca voli')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: fromCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Da (IATA)', hintText: 'es. FCO'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: toCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'A (IATA)', hintText: 'es. JFK'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Data'),
            subtitle: Text(d != null ? '${d.day}/${d.month}/${d.year}' : 'Seleziona'),
            trailing: const Icon(Icons.calendar_today_rounded),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
                initialDate: d ?? now,
              );
              if (picked != null) setState(() => date = picked);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Per ora: mock risultati
              final query = '${fromCtrl.text} → ${toCtrl.text} (${date != null ? '${date!.day}/${date!.month}' : '?'})';
              showModalBottomSheet(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                builder: (_) => _MockResults(query: query),
              );
            },
            child: const Text('Cerca'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nota: questa è una demo UI. Collegheremo qui le API voli.',
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _MockResults extends StatelessWidget {
  final String query;
  const _MockResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final results = [
      ('AZ 608', 'FCO 15:00 → JFK 18:55', 'Diretto · ITA Airways'),
      ('DL 185', 'FCO 10:30 → JFK 14:25', 'Diretto · Delta'),
      ('LH 231 + LH 400', 'FCO 09:15 → FRA → JFK 16:45', '1 scalo · Lufthansa'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Risultati per $query', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...results.map((r) => Card(
                child: ListTile(
                  title: Text(r.$1),
                  subtitle: Text('${r.$2}\n${r.$3}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              )),
        ],
      ),
    );
  }
}
