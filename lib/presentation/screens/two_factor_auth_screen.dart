import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/services/mfa_service.dart';
import '../../data/services/auth_service.dart';

class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  bool _isLoading = true;
  bool _isMfaEnabled = false;
  bool _isEnrolling = false;
  
  String? _factorId;
  String? _qrCodeUri;
  String? _secret;
  
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkMfaStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkMfaStatus() async {
    setState(() => _isLoading = true);
    
    try {
      // Prima pulisci eventuali fattori non verificati rimasti da sessioni precedenti
      await MfaService.cleanupUnverifiedFactors();
      
      // Poi controlla lo stato reale
      final isEnabled = await MfaService.isMfaEnabled();
      
      if (mounted) {
        setState(() {
          _isMfaEnabled = isEnabled;
          _isLoading = false;
          
          // Reset dello stato di enrollment se torniamo alla schermata
          _isEnrolling = false;
          _factorId = null;
          _qrCodeUri = null;
          _secret = null;
          _codeController.clear();
        });
        
        print('🔵 Stato 2FA: ${isEnabled ? "ATTIVO" : "DISATTIVO"}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Errore durante il controllo dello stato 2FA');
      }
    }
  }

  Future<void> _toggleMfa(bool value) async {
    if (value) {
      // Attiva il 2FA - prima verifica che non sia già attivo
      if (_isMfaEnabled) {
        _showError('2FA già attivo');
        return;
      }
      await _startMfaEnrollment();
    } else {
      // Disattiva il 2FA
      if (!_isMfaEnabled) {
        _showError('2FA già disattivato');
        return;
      }
      await _disableMfa();
    }
  }

  Future<void> _startMfaEnrollment() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await MfaService.enrollMfa();
      
      // Verifica che totp e secret esistano
      final secret = response.totp?.secret;
      if (secret == null) {
        throw Exception('Errore: secret non disponibile');
      }
      
      final email = AuthService.currentUser?.email ?? 'user@travelshare.com';
      final qrUri = MfaService.generateQrCodeUri(
        secret: secret,
        email: email,
      );
      
      setState(() {
        _isEnrolling = true;
        _factorId = response.id;
        _qrCodeUri = qrUri;
        _secret = secret;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Errore durante l\'attivazione del 2FA: $e');
    }
  }

  Future<void> _verifyAndEnableMfa() async {
    if (_codeController.text.isEmpty) {
      _showError('Inserisci il codice di verifica');
      return;
    }

    if (_factorId == null) {
      _showError('Errore: ID fattore non trovato');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await MfaService.verifyMfaEnrollment(
        factorId: _factorId!,
        code: _codeController.text.trim(),
      );
      
      setState(() {
        _isMfaEnabled = true;
        _isEnrolling = false;
        _isLoading = false;
        _codeController.clear();
        _factorId = null;
        _qrCodeUri = null;
        _secret = null;
      });
      
      _showSuccess('Autenticazione a due fattori attivata con successo!');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError(e.toString());
    }
  }

  Future<void> _disableMfa() async {
    // Conferma prima di disabilitare
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disabilita 2FA'),
        content: const Text(
          'Sei sicuro di voler disabilitare l\'autenticazione a due fattori? '
          'Il tuo account sarà meno sicuro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disabilita'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    
    try {
      await MfaService.disableMfa();
      
      setState(() {
        _isMfaEnabled = false;
        _isLoading = false;
      });
      
      _showSuccess('Autenticazione a due fattori disabilitata');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Errore durante la disabilitazione: $e');
    }
  }

  Future<void> _cancelEnrollment() async {
    // Conferma prima di annullare
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annulla configurazione'),
        content: const Text(
          'Sei sicuro di voler annullare? Dovrai ricominciare da capo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continua configurazione'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Pulisci il fattore non verificato
      // --- MODIFICA QUI ---
      if (_factorId != null) {
        // Usa il metodo specifico invece di quello generico
        await MfaService.unenrollFactor(_factorId!);
      } else {
        // Fallback se _factorId è nullo (non dovrebbe succedere)
        await MfaService.cleanupUnverifiedFactors();
      }
      // --- FINE MODIFICA ---
      
      if (mounted) {
        setState(() {
          _isEnrolling = false;
          _factorId = null;
          _qrCodeUri = null;
          _secret = null;
          _codeController.clear();
          _isLoading = false;
        });
        
        // Non è necessario ricaricare lo stato, lo conosciamo già
        // await _checkMfaStatus(); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Errore durante l\'annullamento: $e');
      }
    }
  }

  void _copySecret() {
    if (_secret != null) {
      Clipboard.setData(ClipboardData(text: _secret!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chiave segreta copiata negli appunti'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Se siamo in modalità enrollment, pulisci prima di tornare indietro
        // --- MODIFICA QUI ---
        if (_isEnrolling && _factorId != null) {
          await MfaService.unenrollFactor(_factorId!);
        } else if (_isEnrolling) {
          // Fallback
          await MfaService.cleanupUnverifiedFactors();
        }
        // --- FINE MODIFICA ---
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Autenticazione a due fattori'),
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isEnrolling
                ? _buildEnrollmentView()
                : _buildStatusView(),
      ),
    );
  }

  Widget _buildStatusView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icona stato
          Icon(
            _isMfaEnabled ? Icons.verified_user : Icons.security,
            size: 80,
            color: _isMfaEnabled ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 24),

          // Titolo
          Text(
            _isMfaEnabled
                ? 'Autenticazione a due fattori attiva'
                : 'Autenticazione a due fattori',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Descrizione
          Text(
            _isMfaEnabled
                ? 'Il tuo account è protetto con l\'autenticazione a due fattori. '
                    'Ad ogni accesso dovrai inserire un codice di verifica oltre alla password.'
                : 'Aggiungi un ulteriore livello di sicurezza al tuo account richiedendo '
                    'un codice di verifica oltre alla password quando accedi.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Toggle Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isMfaEnabled
                  ? Colors.green.shade50
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isMfaEnabled
                    ? Colors.green.shade200
                    : Colors.blue.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isMfaEnabled ? Icons.check_circle : Icons.security,
                  color: _isMfaEnabled ? Colors.green : Colors.blue,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isMfaEnabled ? 'Protezione Attiva' : 'Protezione Inattiva',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isMfaEnabled
                              ? Colors.green.shade900
                              : Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isMfaEnabled
                            ? 'Account protetto con 2FA'
                            : 'Attiva per maggiore sicurezza',
                        style: TextStyle(
                          fontSize: 13,
                          color: _isMfaEnabled
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isMfaEnabled,
                  onChanged: _toggleMfa,
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Come funziona
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Come funziona',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoItem(
                  icon: Icons.phone_android,
                  title: 'App Authenticator',
                  description: 'Usa un\'app come Google Authenticator o Microsoft Authenticator',
                ),
                const SizedBox(height: 12),
                _buildInfoItem(
                  icon: Icons.qr_code,
                  title: 'Configurazione rapida',
                  description: 'Scansiona un QR code per configurare in pochi secondi',
                ),
                const SizedBox(height: 12),
                _buildInfoItem(
                  icon: Icons.lock,
                  title: 'Sicurezza extra',
                  description: 'Codice univoco richiesto ad ogni accesso',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // App consigliate (solo se non attivo)
          if (!_isMfaEnabled)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Authenticator consigliate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAppTile(
                    icon: Icons.g_mobiledata,
                    name: 'Google Authenticator',
                    description: 'Gratuita • iOS & Android',
                  ),
                  const SizedBox(height: 12),
                  _buildAppTile(
                    icon: Icons.window,
                    name: 'Microsoft Authenticator',
                    description: 'Gratuita • iOS & Android',
                  ),
                  const SizedBox(height: 12),
                  _buildAppTile(
                    icon: Icons.security,
                    name: 'Authy',
                    description: 'Gratuita • iOS & Android • Multi-device',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade700, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnrollmentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Icon(
            Icons.qr_code_scanner,
            size: 64,
            color: Colors.blue.shade600,
          ),
          const SizedBox(height: 16),
          const Text(
            'Configura 2FA',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Segui i passaggi per completare la configurazione',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Step 1
          _buildStepCard(
            stepNumber: '1',
            title: 'Scansiona il QR Code',
            description: 'Apri la tua app authenticator e scansiona questo codice:',
            child: Column(
              children: [
                const SizedBox(height: 16),
                if (_qrCodeUri != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: QrImageView(
                      data: _qrCodeUri!,
                      version: QrVersions.auto,
                      size: 200,
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Oppure inserisci manualmente questa chiave:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _secret ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: _copySecret,
                        tooltip: 'Copia',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Step 2
          _buildStepCard(
            stepNumber: '2',
            title: 'Inserisci il codice di verifica',
            description: 'Inserisci il codice a 6 cifre generato dalla tua app:',
            child: Column(
              children: [
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Bottoni
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancelEnrollment,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Annulla'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _verifyAndEnableMfa,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Verifica e Attiva',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildAppTile({
    required IconData icon,
    required String name,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
}