import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/services/mfa_service.dart';

class MfaVerificationScreen extends StatefulWidget {
  final String factorId;
  final String challengeId;
  final VoidCallback onVerificationSuccess;

  const MfaVerificationScreen({
    super.key,
    required this.factorId,
    required this.challengeId,
    required this.onVerificationSuccess,
  });

  @override
  State<MfaVerificationScreen> createState() => _MfaVerificationScreenState();
}

class _MfaVerificationScreenState extends State<MfaVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  int _remainingTime = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() => _remainingTime--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) {
      _showError('Inserisci un codice a 6 cifre');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await MfaService.verifyMfaCode(
        factorId: widget.factorId,
        challengeId: widget.challengeId,
        code: _codeController.text.trim(),
      );

      if (!mounted) return;

      // Verifica completata con successo
      widget.onVerificationSuccess();
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      _codeController.clear();
      
      String errorMessage = 'Codice non valido';
      if (e.toString().contains('expired')) {
        errorMessage = 'Codice scaduto. Riprova.';
      }
      
      _showError(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifica in due passaggi'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Icona
              Icon(
                Icons.security,
                size: 80,
                color: Colors.blue.shade600,
              ),
              const SizedBox(height: 24),

              // Titolo
              const Text(
                'Inserisci il codice di verifica',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Descrizione
              Text(
                'Apri la tua app authenticator e inserisci il codice a 6 cifre',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Campo input codice
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                onChanged: (value) {
                  // Verifica automaticamente quando si inseriscono 6 cifre
                  if (value.length == 6 && !_isLoading) {
                    _verifyCode();
                  }
                },
              ),
              const SizedBox(height: 24),

              // Timer
              if (_remainingTime > 0)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Codice valido per $_remainingTime secondi',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // Bottone verifica
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verifica',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Link aiuto
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Serve aiuto?'),
                      content: const Text(
                        'Se non riesci ad accedere:\n\n'
                        '1. Verifica che l\'orario del tuo dispositivo sia corretto\n'
                        '2. Assicurati di usare l\'app authenticator corretta\n'
                        '3. Controlla di inserire il codice prima che scada\n\n'
                        'Se il problema persiste, contatta il supporto.',
                        style: TextStyle(height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Non riesci ad accedere?'),
              ),

              const Spacer(),

              // Info sicurezza
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Il tuo account è protetto con l\'autenticazione a due fattori',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade900,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}