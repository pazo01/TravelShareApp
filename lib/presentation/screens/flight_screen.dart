// lib/presentation/screens/flight_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/flight_service.dart';
import '../../data/services/trip_service.dart';
import '../../data/services/matching_service.dart';
import '../../data/services/group_service.dart';
import '../../core/config/supabase_config.dart';
import 'destination_picker_screen.dart';
import 'home_screen.dart';

class FlightScreen extends StatefulWidget {
  const FlightScreen({super.key});

  @override
  State<FlightScreen> createState() => _FlightScreenState();
}

class _FlightScreenState extends State<FlightScreen> {
  final _flightNumberController = TextEditingController();
  final _flightService = FlightService();
  final _tripService = TripService();
  
  DateTime? _selectedDate;
  Map<String, dynamic>? _flightData;
  FlightInfo? _flightInfo;
  Map<String, dynamic>? _selectedDestination;
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Step tracker
  int _currentStep = 0; // 0: flight, 1: destination, 2: confirm

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuovo Viaggio'),
        centerTitle: true,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _handleStepContinue,
        onStepCancel: _handleStepCancel,
        onStepTapped: (step) {
          if (step < _currentStep) {
            setState(() => _currentStep = step);
          }
        },
        controlsBuilder: (context, details) {
          return Row(
            children: [
              if (_currentStep > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Indietro'),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : details.onStepContinue,
                child: Text(_currentStep == 2 ? 'Conferma' : 'Avanti'),
              ),
            ],
          );
        },
        steps: [
          // STEP 1: Ricerca Volo
          Step(
            title: const Text('Cerca il tuo volo'),
            content: _buildFlightSearchStep(),
            isActive: _currentStep >= 0,
            state: _flightInfo != null ? StepState.complete : StepState.indexed,
          ),
          
          // STEP 2: Selezione Destinazione
          Step(
            title: const Text('Destinazione finale'),
            content: _buildDestinationStep(),
            isActive: _currentStep >= 1,
            state: _selectedDestination != null ? StepState.complete : StepState.indexed,
          ),
          
          // STEP 3: Conferma
          Step(
            title: const Text('Conferma dettagli'),
            content: _buildConfirmationStep(),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }

  Widget _buildFlightSearchStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Flight number input
        TextField(
          controller: _flightNumberController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Numero Volo',
            hintText: 'Es: AZ123, FR456',
            prefixIcon: const Icon(Icons.flight_takeoff),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Date picker
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.grey),
                const SizedBox(width: 12),
                Text(
                  _selectedDate != null
                      ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                      : 'Seleziona data volo',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedDate != null ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Search button
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _searchFlight,
          icon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search),
          label: Text(_isLoading ? 'Ricerca...' : 'Cerca Volo'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        
        // Error message
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // Flight info card
        if (_flightInfo != null) ...[
          const SizedBox(height: 16),
          _buildFlightInfoCard(),
        ],
      ],
    );
  }

  Widget _buildFlightInfoCard() {
    if (_flightInfo == null) return const SizedBox();
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${_flightInfo!.airline} • ${_flightInfo!.flightNumber}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(_flightInfo!.statusDisplay),
                  backgroundColor: _getStatusColor(),
                ),
              ],
            ),
            const Divider(),
            
            // Route
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _flightInfo!.departureIata,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _flightInfo!.departureAirport,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.flight_takeoff, color: Colors.blue),
                const SizedBox(width: 16),
                const Icon(Icons.flight_land, color: Colors.green),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _flightInfo!.arrivalIata,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _flightInfo!.arrivalAirport,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Arrival time
            if (_flightInfo!.scheduledArrival != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.access_time, color: Colors.orange),
                title: const Text('Arrivo previsto'),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(_flightInfo!.scheduledArrival!),
                ),
                dense: true,
              ),
            ],
            
            // Terminal and Gate info
            if (_flightInfo!.terminal != null || _flightInfo!.gate != null) ...[
              Row(
                children: [
                  if (_flightInfo!.terminal != null) ...[
                    Chip(
                      avatar: const Icon(Icons.domain, size: 16),
                      label: Text('Terminal ${_flightInfo!.terminal}'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (_flightInfo!.gate != null)
                    Chip(
                      avatar: const Icon(Icons.door_front_door, size: 16),
                      label: Text('Gate ${_flightInfo!.gate}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedDestination == null) ...[
          const Text(
            'Dove devi andare dopo l\'atterraggio?',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _selectDestination,
            icon: const Icon(Icons.location_on),
            label: const Text('Seleziona Destinazione'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ] else ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red, size: 40),
              title: const Text('Destinazione selezionata'),
              subtitle: Text(_selectedDestination!['address'] ?? 'Posizione personalizzata'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _selectDestination,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Info about flexible radius (future implementation)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Prossimamente: potrai impostare un raggio flessibile per trovare più compagni di viaggio!',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Riepilogo del tuo viaggio:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Flight summary
        if (_flightInfo != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.flight, color: Colors.blue),
              title: Text('${_flightInfo!.airline} ${_flightInfo!.flightNumber}'),
              subtitle: Text('${_flightInfo!.departureIata} → ${_flightInfo!.arrivalIata}'),
            ),
          ),
        
        // Destination summary
        if (_selectedDestination != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: const Text('Destinazione'),
              subtitle: Text(_selectedDestination!['address'] ?? 'Posizione selezionata'),
            ),
          ),
        
        const SizedBox(height: 24),
        
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _createTrip,
          icon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle),
          label: Text(_isLoading ? 'Salvataggio...' : 'Crea Viaggio e Trova Compagni'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    if (_flightInfo == null) return Colors.grey.shade100;
    switch (_flightInfo!.status) {
      case 'active': return Colors.green.shade100;
      case 'landed': return Colors.blue.shade100;
      case 'cancelled': return Colors.red.shade100;
      case 'diverted': return Colors.orange.shade100;
      default: return Colors.grey.shade100;
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _errorMessage = null;
      });
    }
  }

  Future<void> _searchFlight() async {
    final flightNumber = _flightNumberController.text.trim();
    
    if (flightNumber.isEmpty) {
      setState(() => _errorMessage = 'Inserisci il numero del volo');
      return;
    }
    
    if (_selectedDate == null) {
      setState(() => _errorMessage = 'Seleziona la data del volo');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _flightService.getFlightInfo(flightNumber, date: _selectedDate);
      
      if (data != null) {
        final info = FlightService.parseFlightData(data);
        setState(() {
          _flightData = data;
          _flightInfo = info;
          _isLoading = false;
        });
        
        _showSuccess('Volo trovato! Procedi con la destinazione.');
      } else {
        setState(() {
          _errorMessage = 'Volo non trovato. Verifica il numero e la data.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDestination() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DestinationPickerScreen(),
      ),
    );
    
    if (result != null) {
      setState(() {
        _selectedDestination = result;
      });
    }
  }

  void _handleStepContinue() {
    if (_currentStep == 0) {
      // Verifica che il volo sia stato cercato
      if (_flightInfo == null) {
        setState(() => _errorMessage = 'Cerca prima il tuo volo');
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // Verifica che la destinazione sia selezionata
      if (_selectedDestination == null) {
        _showError('Seleziona la destinazione');
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      _createTrip();
    }
  }

  void _handleStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    }
  }

  Future<void> _createTrip() async {
    if (_flightInfo == null || _selectedDestination == null) {
      _showError('Dati mancanti. Ricontrolla il volo e la destinazione.');
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Salva il viaggio nel database
      final trip = await _tripService.createTrip(
        flightNumber: _flightInfo!.flightNumber,
        airline: _flightInfo!.airline,
        departureAirport: _flightInfo!.departureAirport,
        arrivalAirport: _flightInfo!.arrivalAirport,
        scheduledArrival: _flightInfo!.scheduledArrival,
        destinationAddress: _selectedDestination!['address'] ?? 'Posizione personalizzata',
        destinationLat: _selectedDestination!['lat'] ?? 0.0,
        destinationLng: _selectedDestination!['lng'] ?? 0.0,
        status: _flightInfo!.status,
        additionalFlightData: _flightData,
      );

      if (!mounted) return;

      // 🔥 MATCHING AUTOMATICO - cerca altri viaggiatori compatibili
      final tripId = trip?['id'];
      print('🔍 Avvio matching per trip $tripId...');

      try {
        final user = SupabaseConfig.client.auth.currentUser;
        final scheduledArrival = _flightInfo!.scheduledArrival;

        // Verifica che abbiamo tutti i dati necessari per il matching
        if (user != null && scheduledArrival != null && tripId != null) {
          final matchResponse = await MatchingService.findCompatibleTrips(
            userId: user.id,
            arrivalAirport: _flightInfo!.arrivalAirport,
            scheduledArrival: scheduledArrival,
          );

          if (matchResponse.isNotEmpty) {
            print('✅ Trovati ${matchResponse.length} match compatibili!');

            // Crea o unisciti a un gruppo
            final currentTrip = {
              'trip_id': tripId,
              'user_id': user.id,
            };
            final allTrips = [...matchResponse, currentTrip];

            await GroupService.createOrJoinGroup(matchedTrips: allTrips);
            print('🎉 Gruppo creato/aggiornato con successo!');
          } else {
            print('ℹ️ Nessun match trovato al momento. Il viaggio resta in attesa.');
          }
        } else {
          print('⚠️ Dati mancanti per matching (user: ${user != null}, scheduledArrival: ${scheduledArrival != null}, tripId: ${tripId != null})');
        }
      } catch (matchError) {
        print('⚠️ Errore durante matching (non bloccante): $matchError');
        // Non blocchiamo il flusso se il matching fallisce
      }
      
      // Mostra dialog di successo
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('Viaggio Creato!'),
              ],
            ),
            content: const Text(
              'Il tuo viaggio è stato salvato con successo.\n\n'
              'Ora stiamo cercando compagni di viaggio che condividono il tuo stesso volo e una destinazione simile.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Chiude il dialog
                  // Naviga alla HomeScreen nella tab "I miei viaggi" (indice 1)
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(initialIndex: 1),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('Vai ai miei viaggi'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Chiude il dialog
                  _resetForm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Crea un altro viaggio'),
              ),
            ],
          );
        },
      );
      
      setState(() => _isLoading = false);
      
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Errore nel salvataggio: ${e.toString()}');
    }
  }

  void _resetForm() {
    setState(() {
      _flightNumberController.clear();
      _selectedDate = null;
      _flightData = null;
      _flightInfo = null;
      _selectedDestination = null;
      _errorMessage = null;
      _currentStep = 0;
    });
    _showSuccess('Pronto per creare un nuovo viaggio!');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    super.dispose();
  }
}