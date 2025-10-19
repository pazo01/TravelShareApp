import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _otpSent = false;
  
  // Codici paese comuni
  final List<CountryCode> _countryCodes = [
    CountryCode(name: 'Italia', code: '+39', flag: '🇮🇹'),
    CountryCode(name: 'Francia', code: '+33', flag: '🇫🇷'),
    CountryCode(name: 'Germania', code: '+49', flag: '🇩🇪'),
    CountryCode(name: 'Spagna', code: '+34', flag: '🇪🇸'),
    CountryCode(name: 'Regno Unito', code: '+44', flag: '🇬🇧'),
    CountryCode(name: 'USA', code: '+1', flag: '🇺🇸'),
  ];
  
  CountryCode _selectedCountry = CountryCode(
    name: 'Italia',
    code: '+39',
    flag: '🇮🇹',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accedi con Telefono'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _otpSent ? _buildOtpView() : _buildPhoneView(),
        ),
      ),
    );
  }

  Widget _buildPhoneView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.phone_android,
          size: 80,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 20),
        const Text(
          'Verifica il tuo numero',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Ti invieremo un codice SMS per verificare il tuo numero di telefono',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        
        // Selettore paese + input telefono
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Country code selector
            InkWell(
              onTap: _showCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedCountry.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedCountry.code,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Phone number input
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: InputDecoration(
                  labelText: 'Numero di telefono',
                  hintText: _selectedCountry.code == '+39' 
                      ? '3XX XXX XXXX' 
                      : 'Numero',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Info box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Il tuo numero verrà utilizzato solo per l\'autenticazione',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade900,
                  ),
                ),
              ),
            ],
          ),
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
                    'Invia Codice',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.sms_outlined,
          size: 80,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 20),
        const Text(
          'Inserisci il codice',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Abbiamo inviato un codice al numero\n${_selectedCountry.code} ${_phoneController.text}',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        
        // OTP Input
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            hintText: '000000',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onChanged: (value) {
            if (value.length == 6) {
              _verifyOtp();
            }
          },
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
                    'Verifica',
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
            Text(
              'Non hai ricevuto il codice?',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            TextButton(
              onPressed: _resendOtp,
              child: const Text(
                'Invia di nuovo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        
        TextButton(
          onPressed: () {
            setState(() {
              _otpSent = false;
              _otpController.clear();
            });
          },
          child: const Text('Cambia numero'),
        ),
      ],
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Seleziona Paese',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListView.builder(
                shrinkWrap: true,
                itemCount: _countryCodes.length,
                itemBuilder: (context, index) {
                  final country = _countryCodes[index];
                  return ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 32),
                    ),
                    title: Text(country.name),
                    trailing: Text(
                      country.code,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedCountry = country);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty || phone.length < 9) {
      _showError('Inserisci un numero di telefono valido');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // IMPORTANTE: Formato E.164 richiesto da Twilio
      // Esempio: +393123456789 (senza spazi)
      final fullPhone = '${_selectedCountry.code}$phone';
      
      print('📞 Invio OTP a: $fullPhone'); // Debug
      
      await AuthService.signInWithPhone(fullPhone);
      
      if (mounted) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
        _showSuccess('Codice inviato con successo!');
      }
    } catch (e) {
      print('🔴 Errore invio OTP: $e'); // Debug
      _showError('Errore: ${e.toString()}');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    
    if (otp.length != 6) {
      _showError('Inserisci il codice completo (6 cifre)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullPhone = '${_selectedCountry.code}${_phoneController.text.trim()}';
      
      print('✅ Verifica OTP: $otp per $fullPhone'); // Debug
      
      await AuthService.verifyOTP(
        token: otp,
        type: OtpType.sms,
        phone: fullPhone,
      );
      
      if (mounted) {
        _showSuccess('Accesso effettuato con successo!');
        // TODO: Navigate to home
      }
    } catch (e) {
      print('🔴 Errore verifica OTP: $e'); // Debug
      _showError('Codice non valido: ${e.toString()}');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _otpSent = false);
    _otpController.clear();
    await _sendOtp();
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}

class CountryCode {
  final String name;
  final String code;
  final String flag;

  CountryCode({
    required this.name,
    required this.code,
    required this.flag,
  });
}