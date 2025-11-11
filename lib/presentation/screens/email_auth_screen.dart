import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- 1. IMPORT AGGIUNTO
import '../../data/services/auth_service.dart';
import '../../data/services/mfa_service.dart';
import 'password_recovery_screen.dart';
import 'mfa_verification_screen.dart';
import 'home_screen.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _awaitingOtpVerification = false;
  String? _registrationEmail;

  // Stato per la sicurezza della password
  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthLabel = '';
      });
      return;
    }

    double strength = 0;
    String label = 'Debole';

    if (password.length >= 8) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.25;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.25;

    if (strength <= 0.25) {
      label = 'Debole';
    } else if (strength <= 0.5) {
      label = 'Media';
    } else if (strength <= 0.75) {
      label = 'Forte';
    } else {
      label = 'Molto Forte';
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = label;
    });
  }

  Widget _buildPasswordStrengthIndicator() {
    if (_passwordStrengthLabel.isEmpty) return const SizedBox.shrink();

    Color color;
    if (_passwordStrength <= 0.25) {
      color = Colors.red;
    } else if (_passwordStrength <= 0.5) {
      color = Colors.orange;
    } else if (_passwordStrength <= 0.75) {
      color = Colors.yellow.shade700;
    } else {
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: Colors.grey.shade300,
            color: color,
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Text(
            'Sicurezza: $_passwordStrengthLabel',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_awaitingOtpVerification
            ? 'Verifica Email'
            : (_isLogin ? 'Accedi' : 'Registrati')),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _awaitingOtpVerification
              ? _buildOtpVerificationForm()
              : _buildAuthForm(),
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Icon(
            Icons.email_outlined,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            _isLogin ? 'Bentornato!' : 'Crea il tuo account',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _isLogin
                ? 'Accedi con la tua email'
                : 'Inizia a risparmiare oggi',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // Nome (solo per registrazione)
          if (!_isLogin) ...[
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (!_isLogin && (value == null || value.isEmpty)) {
                  return 'Inserisci il tuo nome';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Inserisci la tua email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return 'Email non valida';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            onChanged: (value) {
              if (!_isLogin) {
                _updatePasswordStrength(value);
              }
            },
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Inserisci la password';
              }
              if (!_isLogin && value.length < 6) {
                return 'La password deve essere di almeno 6 caratteri';
              }
              return null;
            },
          ),

          // Indicatore sicurezza (solo registrazione)
          if (!_isLogin) _buildPasswordStrengthIndicator(),
          
          const SizedBox(height: 16),

          // Conferma Password (solo registrazione)
          if (!_isLogin) ...[
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Conferma Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (!_isLogin && value != _passwordController.text) {
                  return 'Le password non corrispondono';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          // Password dimenticata (solo login)
          if (_isLogin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _goToPasswordRecovery,
                child: const Text('Password dimenticata?'),
              ),
            ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _isLogin ? 'Accedi' : 'Registrati',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // Toggle login/register
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isLogin
                    ? 'Non hai un account? '
                    : 'Hai già un account? ',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _formKey.currentState?.reset();
                    _confirmPasswordController.clear();
                    _updatePasswordStrength('');
                  });
                },
                child: Text(
                  _isLogin ? 'Registrati' : 'Accedi',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpVerificationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 80,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 20),
        const Text(
          'Verifica la tua email',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Abbiamo inviato un codice di verifica a\n$_registrationEmail',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 40),

        // OTP Input
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          maxLength: 6,
          decoration: InputDecoration(
            labelText: 'Codice OTP',
            hintText: '000000',
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.pin_outlined),
          ),
        ),

        const SizedBox(height: 24),

        // Verify button
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleOtpVerification,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Verifica Codice',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 16),

        // Resend OTP
        TextButton(
          onPressed: _isLoading ? null : _resendOtp,
          child: const Text('Non hai ricevuto il codice? Invia di nuovo'),
        ),

        const SizedBox(height: 16),

        // Cancel button
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _awaitingOtpVerification = false;
                    _otpController.clear();
                  });
                },
          child: const Text('Torna indietro'),
        ),

        const SizedBox(height: 24),

        // Info box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Controlla anche la cartella spam se non vedi l\'email',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// FUNZIONE _handleSubmit CON SUPPORTO 2FA
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    final email = _emailController.text.trim();

    try {
      if (_isLogin) {
        // --- LOGIN CON CONTROLLO 2FA ---
        final response = await AuthService.signInWithEmail(
          email: email,
          password: _passwordController.text,
        );
        
        if (!mounted) return;
        
        // Controlla se il 2FA è abilitato per questo utente
        final isMfaEnabled = await MfaService.isMfaEnabled();
        
        if (isMfaEnabled) {
          // 2FA è attivo, ottieni i fattori MFA
          final factors = await MfaService.getFactors();
          
          final totpFactors = factors.totp;
          if (totpFactors != null && totpFactors.isNotEmpty) {
            // Trova il primo fattore verificato
            final factor = totpFactors.firstWhere(
              // --- 2. ECCO LA CORREZIONE ---
              (f) => f.status == FactorStatus.verified,
              // --- FINE CORREZIONE ---
            );
            
            // Crea una challenge
            final challenge = await MfaService.createChallenge(factor.id);
            
            if (!mounted) return;
            
            // Naviga alla schermata di verifica 2FA
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MfaVerificationScreen(
                  factorId: factor.id,
                  challengeId: challenge.id,
                  onVerificationSuccess: () {
                    // Verifica completata con successo
                    if (mounted) {
                      _showSuccess('Accesso effettuato con successo!');
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
            );
            
            setState(() => _isLoading = false);
            return;
          }
        }
        
        // Se non c'è 2FA, procedi normalmente
        _showSuccess('Accesso effettuato con successo!');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
        
      } else {
        // --- REGISTRAZIONE ---
        bool emailExists = await AuthService.checkEmailExists(email: email);

        if (emailExists) {
          _showError('Questa email è già registrata. Prova ad accedere.');
          setState(() => _isLoading = false);
          return;
        }

        _registrationEmail = email;
        await AuthService.signUpWithEmailOtp(
          email: _registrationEmail!,
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
        );
        
        if (mounted) {
          setState(() {
            _awaitingOtpVerification = true;
            _isLoading = false;
          });
          _showSuccess('Codice inviato! Controlla la tua email.');
        }
      }
    } catch (e) {
      _showError('Errore: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOtpVerification() async {
    if (_otpController.text.isEmpty || _otpController.text.length != 6) {
      _showError('Inserisci un codice OTP valido di 6 cifre');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.verifyEmailOtp(
        email: _registrationEmail!,
        token: _otpController.text.trim(),
      );

      if (mounted) {
        _showSuccess('Email verificata! Ora puoi accedere.');
        setState(() {
          _awaitingOtpVerification = false;
          _isLogin = true;
          _otpController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
          _updatePasswordStrength('');
        });
      }
    } catch (e) {
      _showError('Codice non valido o scaduto: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);

    try {
      await AuthService.resendEmailOtp(email: _registrationEmail!);
      _showSuccess('Nuovo codice inviato!');
    } catch (e) {
      _showError('Errore nell\'invio del codice: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToPasswordRecovery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PasswordRecoveryScreen(
          email: _emailController.text.trim(),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}