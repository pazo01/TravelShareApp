import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhonePasswordRecoveryScreen extends StatefulWidget {
  final String? phone;

  const PhonePasswordRecoveryScreen({super.key, this.phone});

  @override
  State<PhonePasswordRecoveryScreen> createState() =>
      _PhonePasswordRecoveryScreenState();
}

class _PhonePasswordRecoveryScreenState
    extends State<PhonePasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.phone != null) {
      _phoneController.text = widget.phone!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recupera Password'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildCurrentView(),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    if (_otpVerified) {
      return _buildResetPasswordView();
    } else if (_otpSent) {
      return _buildOtpVerificationView();
    } else {
      return _buildPhoneInputView();
    }
  }

  // Vista 1: Inserimento numero di telefono
  Widget _buildPhoneInputView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.phone_android,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 20),
          const Text(
            'Password dimenticata?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Inserisci il tuo numero di telefono e ti invieremo un codice OTP per reimpostare la password',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Numero di Telefono',
              hintText: '+39 123 456 7890',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Inserisci il tuo numero di telefono';
              }
              if (!value.startsWith('+')) {
                return 'Il numero deve iniziare con + (es: +39...)';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendOtp,
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
                      'Invia Codice OTP',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Vista 2: Verifica OTP
  Widget _buildOtpVerificationView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.lock_clock,
          size: 80,
          color: Colors.blue,
        ),
        const SizedBox(height: 20),
        const Text(
          'Verifica Codice OTP',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Inserisci il codice OTP a 6 cifre inviato a\n${_phoneController.text}',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            labelText: 'Codice OTP',
            hintText: '123456',
            prefixIcon: const Icon(Icons.dialpad),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _otpSent = false;
                        _otpController.clear();
                      });
                    },
              child: const Text('Cambia numero'),
            ),
            const Text(' | '),
            TextButton(
              onPressed: _isLoading ? null : _sendOtp,
              child: const Text('Invia di nuovo'),
            ),
          ],
        ),
      ],
    );
  }

  // Vista 3: Reimposta password
  Widget _buildResetPasswordView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.lock_reset,
            size: 80,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 20),
          const Text(
            'Crea Nuova Password',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Scegli una password sicura per il tuo account',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Nuova Password
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              labelText: 'Nuova Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(
                    () => _obscureNewPassword = !_obscureNewPassword,
                  );
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Inserisci la nuova password';
              }
              if (value.length < 6) {
                return 'La password deve essere di almeno 6 caratteri';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Conferma Password
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
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Conferma la password';
              }
              if (value != _newPasswordController.text) {
                return 'Le password non coincidono';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Password requirements
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Requisiti password:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRequirement('Almeno 6 caratteri'),
                _buildRequirement('Lettere e numeri'),
                _buildRequirement('Caratteri speciali consigliati'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _resetPassword,
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Reimposta Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  // Logica: Invia OTP
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      
      print('🔵 [PHONE_RECOVERY] Invio OTP al numero: $phone');

      // Invia OTP per reset password via telefono
      await Supabase.instance.client.auth.signInWithOtp(
        phone: phone,
      );

      print('🟢 [PHONE_RECOVERY] OTP inviato con successo');

      if (mounted) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Codice OTP inviato al tuo telefono!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('🔴 [PHONE_RECOVERY] Errore invio OTP: $e');
      
      String errorMessage = 'Errore invio OTP';
      if (e.toString().contains('not found') || 
          e.toString().contains('User not found')) {
        errorMessage = 'Numero di telefono non associato a nessun account';
      } else if (e.toString().contains('invalid phone')) {
        errorMessage = 'Formato numero non valido';
      }
      
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Logica: Verifica OTP
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      _showError('Inserisci il codice OTP a 6 cifre');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      
      print('🔵 [PHONE_RECOVERY] Verifica OTP per: $phone');

      // Verifica OTP
      final authResponse = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.sms,
        phone: phone,
        token: otp,
      );

      if (authResponse.user == null) {
        throw Exception('Verifica OTP fallita');
      }

      print('🟢 [PHONE_RECOVERY] OTP verificato con successo');

      if (mounted) {
        setState(() {
          _otpVerified = true;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Codice verificato! Ora imposta una nuova password'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('🔴 [PHONE_RECOVERY] Errore verifica OTP: $e');
      
      String errorMessage = 'Codice OTP non valido o scaduto';
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Logica: Reset password
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newPassword = _newPasswordController.text;
      
      print('🔵 [PHONE_RECOVERY] Aggiornamento password...');

      // Aggiorna la password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      print('🟢 [PHONE_RECOVERY] Password aggiornata con successo');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Password aggiornata con successo!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Torna alla schermata di login dopo un breve delay
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      print('🔴 [PHONE_RECOVERY] Errore aggiornamento password: $e');
      _showError('Errore durante l\'aggiornamento della password');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}