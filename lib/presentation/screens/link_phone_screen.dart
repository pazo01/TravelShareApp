import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LinkPhoneScreen extends StatefulWidget {
  const LinkPhoneScreen({super.key});

  @override
  State<LinkPhoneScreen> createState() => _LinkPhoneScreenState();
}

class _LinkPhoneScreenState extends State<LinkPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _otpSent = false;
  bool _debugMode = false;
  
  String _debugInfo = '';
  String? _lastPhoneUsed;
  String? _originalUserId;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _checkCurrentUser() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _originalUserId = user.id;
      print('💾 [LINK_PHONE] User corrente: ${user.id}');
      print('💾 [LINK_PHONE] Email: ${user.email}');
      print('💾 [LINK_PHONE] Phone attuale: ${user.phone}');
    } else {
      print('⚠️ [LINK_PHONE] Nessun utente autenticato');
    }
  }

  // 📱 Invia OTP per associare telefono
  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      _showError('Inserisci un numero di telefono');
      return;
    }

    if (!phone.startsWith('+')) {
      _showError('Il numero deve iniziare con + (es: +39...)');
      return;
    }

    // Verifica che ci sia un utente autenticato
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _showError('Devi essere autenticato per associare un telefono');
      return;
    }

    setState(() {
      _isLoading = true;
      _debugInfo = '📤 Invio OTP per associazione...';
    });

    try {
      print('🔵 [LINK_PHONE] Invio OTP al numero: $phone');
      print('🔵 [LINK_PHONE] User ID: ${currentUser.id}');
      
      // Usa updateUser per aggiungere il telefono
      // Questo invierà un OTP al nuovo numero
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          phone: phone,
        ),
      );

      print('🟢 [LINK_PHONE] OTP inviato con successo');

      setState(() {
        _otpSent = true;
        _isLoading = false;
        _lastPhoneUsed = phone;
        _debugInfo = '✅ OTP inviato a $phone';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Codice OTP inviato! Verifica per confermare.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('🔴 [LINK_PHONE] Errore invio OTP: $e');
      setState(() {
        _isLoading = false;
        _debugInfo = '❌ Errore: $e';
      });
      
      String errorMessage = 'Errore invio OTP';
      
      // Gestione errori specifici
      if (e.toString().contains('already registered') || 
          e.toString().contains('phone_exists')) {
        errorMessage = '⚠️ Questo numero è già associato ad un altro account.\n\n'
                      'Opzioni:\n'
                      '1. Usa un numero diverso\n'
                      '2. Se è il tuo numero, rimuovilo dall\'altro account prima';
        
        // Mostra dialog più dettagliato
        _showPhoneExistsDialog(phone);
        return;
      } else if (e.toString().contains('invalid phone')) {
        errorMessage = 'Formato numero non valido. Usa formato: +39...';
      }
      
      _showError(errorMessage);
    }
  }

  // ✅ Verifica OTP e completa l'associazione
  Future<void> _verifyOTP() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      _showError('Inserisci il codice OTP a 6 cifre');
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _showError('Sessione non valida');
      return;
    }

    setState(() {
      _isLoading = true;
      _debugInfo = '🔐 Verifica OTP...';
    });

    try {
      print('🔵 [LINK_PHONE] Verifica OTP per: $phone');
      print('🔵 [LINK_PHONE] User ID: ${currentUser.id}');

      // Verifica l'OTP per confermare il nuovo telefono
      final authResponse = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.phoneChange,  // 🔑 Importante: usa phoneChange!
        phone: phone,
        token: otp,
      );

      if (authResponse.user == null) {
        throw Exception('Verifica fallita');
      }

      print('🟢 [LINK_PHONE] Telefono associato con successo!');
      print('🟢 [LINK_PHONE] Nuovo phone: ${authResponse.user!.phone}');

      setState(() {
        _isLoading = false;
        _debugInfo = '✅ Telefono associato: $phone';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Telefono associato correttamente!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // 🔧 FIX: Ritorna il numero di telefono invece di true
        await Future.delayed(const Duration(seconds: 1));
        Navigator.of(context).pop(phone);  // Ritorna il numero come String
      }

    } catch (e, stackTrace) {
      print('🔴 [LINK_PHONE] Errore verifica OTP: $e');
      print('🔴 [LINK_PHONE] Stack trace: $stackTrace');
      
      setState(() {
        _isLoading = false;
        _debugInfo = '❌ Errore: $e';
      });

      String errorMessage = 'Errore verifica OTP';
      if (e.toString().contains('invalid') || e.toString().contains('expired')) {
        errorMessage = 'Codice OTP non valido o scaduto';
      } else if (e.toString().contains('already registered')) {
        errorMessage = 'Questo numero è già registrato';
      }

      _showError(errorMessage);
    }
  }

  // 🐛 Debug: controlla sessione
  Future<void> _checkCurrentSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;

      print('🔍 [DEBUG_LINK] Sessione corrente:');
      print('  - Session exists: ${session != null}');
      print('  - User exists: ${user != null}');
      if (user != null) {
        print('  - User ID: ${user.id}');
        print('  - Phone: ${user.phone}');
        print('  - Email: ${user.email}');
      }

      setState(() {
        _debugInfo = user != null 
          ? '👤 User: ${user.email ?? user.id}\n📱 Phone: ${user.phone ?? "Non associato"}'
          : '❌ Nessuna sessione attiva';
      });

    } catch (e) {
      print('🔴 [DEBUG_LINK] Errore: $e');
      setState(() {
        _debugInfo = '❌ Errore: $e';
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Dialog quando il numero è già registrato
  void _showPhoneExistsDialog(String phone) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Numero già registrato'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Il numero $phone è già associato ad un altro account.'),
            const SizedBox(height: 16),
            const Text(
              'Cosa puoi fare:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Usa un numero diverso'),
            const SizedBox(height: 4),
            const Text('• Se è il tuo numero, accedi con quell\'account'),
            const SizedBox(height: 4),
            const Text('• Contatta il supporto per assistenza'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Associa Telefono'),
        actions: [
          IconButton(
            icon: Icon(_debugMode ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () {
              setState(() {
                _debugMode = !_debugMode;
              });
              if (_debugMode) {
                _checkCurrentSession();
              }
            },
            tooltip: 'Toggle Debug Mode',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              const Icon(
                Icons.link,
                size: 60,
                color: Colors.blue,
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                'Associa un numero di telefono al tuo account per una maggiore sicurezza',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              
              const SizedBox(height: 32),
              
              // Campo telefono
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_otpSent && !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Numero di telefono',
                  hintText: '+39 123 456 7890',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Campo OTP
              if (_otpSent) ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Codice OTP',
                    hintText: '123456',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Pulsante principale
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_otpSent ? _verifyOTP : _sendOTP),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _otpSent ? 'Verifica e Associa' : 'Invia Codice OTP',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
              
              // Pulsante reset
              if (_otpSent) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _otpSent = false;
                            _otpController.clear();
                            _debugInfo = '';
                          });
                        },
                  child: const Text('Cambia numero'),
                ),
              ],

              // Debug info
              if (_debugMode) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🐛 DEBUG INFO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _debugInfo.isEmpty ? 'Nessuna info' : _debugInfo,
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (_lastPhoneUsed != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📱 Phone: $_lastPhoneUsed',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                      if (_originalUserId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '🔐 User: ${_originalUserId!.substring(0, 8)}...',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _checkCurrentSession,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Check Session'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}