import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/mfa_service.dart';
import 'password_recovery_screen.dart';
import 'two_factor_auth_screen.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  String? _userEmail;
  bool _isLoading = true;
  bool _isMfaEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final mfaEnabled = await MfaService.isMfaEnabled();
        
        setState(() {
          _userEmail = user.email;
          _isMfaEnabled = mfaEnabled;
        });
      }
    } catch (e) {
      print('🔴 [PRIVACY] Errore caricamento dati: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy e Sicurezza'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Intestazione
                  Icon(
                    Icons.security,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gestisci la sicurezza\ndel tuo account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Sezione Autenticazione a Due Fattori
                  const _SectionHeader(
                    icon: Icons.verified_user,
                    title: 'Autenticazione',
                    subtitle: 'Proteggi il tuo account',
                  ),
                  const SizedBox(height: 12),
                  
                  // 2FA Card
                  _SecurityCard(
                    icon: Icons.security,
                    title: 'Autenticazione a due fattori',
                    subtitle: _isMfaEnabled ? 'Attiva' : 'Non attiva',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isMfaEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Attiva',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TwoFactorAuthScreen(),
                        ),
                      );
                      // Ricarica i dati dopo essere tornati
                      _loadUserData();
                    },
                  ),

                  const SizedBox(height: 32),

                  // Sezione Password
                  const _SectionHeader(
                    icon: Icons.lock_outline,
                    title: 'Password',
                    subtitle: 'Mantieni il tuo account sicuro',
                  ),
                  const SizedBox(height: 12),
                  
                  _SecurityCard(
                    icon: Icons.vpn_key,
                    title: 'Password Account',
                    subtitle: 'Ultima modifica: mai',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showChangePasswordSheet,
                  ),

                  const SizedBox(height: 32),

                  // Sezione Email
                  const _SectionHeader(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    subtitle: 'Gestisci il tuo indirizzo email',
                  ),
                  const SizedBox(height: 12),
                  
                  _SecurityCard(
                    icon: Icons.alternate_email,
                    title: 'Email Account',
                    subtitle: _userEmail ?? 'Non disponibile',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showChangeEmailSheet,
                  ),

                  const SizedBox(height: 32),

                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Mantieni sempre aggiornati i tuoi dati di sicurezza per proteggere il tuo account',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // 🔑 Bottom Sheet per cambiare password
  void _showChangePasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChangePasswordSheet(
        onPasswordChanged: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Password modificata con successo!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  // 📧 Bottom Sheet per cambiare email (placeholder per ora)
  void _showChangeEmailSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChangeEmailSheet(
        currentEmail: _userEmail ?? '',
        onEmailChanged: () {
          _loadUserData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Email modificata con successo!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }
}

// ========================================
// WIDGET: Section Header
// ========================================
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ========================================
// WIDGET: Security Card
// ========================================
class _SecurityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SecurityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================
// BOTTOM SHEET: Change Password
// ========================================
class _ChangePasswordSheet extends StatefulWidget {
  final VoidCallback onPasswordChanged;

  const _ChangePasswordSheet({required this.onPasswordChanged});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Titolo
                Row(
                  children: [
                    Icon(
                      Icons.lock_reset,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cambia Password',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Inserisci la tua password attuale e scegli una nuova password',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Password Attuale
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Password Attuale',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureCurrentPassword =
                              !_obscureCurrentPassword,
                        );
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci la password attuale';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // Link Password Dimenticata
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PasswordRecoveryScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Password dimenticata?',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Nuova Password
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'Nuova Password',
                    prefixIcon: const Icon(Icons.vpn_key),
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
                    if (value == _currentPasswordController.text) {
                      return 'La nuova password deve essere diversa da quella attuale';
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
                    labelText: 'Conferma Nuova Password',
                    prefixIcon: const Icon(Icons.check_circle_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
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

                // Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'La password deve contenere almeno 6 caratteri. Consigliamo di usare lettere, numeri e simboli.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Pulsante Conferma
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleChangePassword,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Cambia Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Verifica password attuale tramite re-autenticazione
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email == null) {
        throw Exception('Utente non autenticato');
      }

      // Prova a fare il login con la password attuale per verificarla
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: user!.email!,
          password: _currentPasswordController.text,
        );
      } catch (e) {
        print('🔴 [PRIVACY] Password attuale errata: $e');
        throw Exception('Password attuale non corretta');
      }

      // 2. Aggiorna la password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      print('🟢 [PRIVACY] Password cambiata con successo');

      if (mounted) {
        Navigator.pop(context);
        widget.onPasswordChanged();
      }
    } on AuthException catch (e) {
      print('🔴 [PRIVACY] AuthException cambio password: ${e.message}');
      
      String errorMessage = 'Errore durante il cambio password';
      
      if (e.message.contains('Invalid login credentials') ||
          e.message.contains('Invalid credentials')) {
        errorMessage = '❌ Password attuale non corretta';
      } else if (e.message.contains('Password should be at least')) {
        errorMessage = '❌ La password deve essere di almeno 6 caratteri';
      } else if (e.message.contains('weak password')) {
        errorMessage = '❌ Password troppo debole. Usa lettere, numeri e simboli';
      } else {
        errorMessage = '❌ ${e.message}';
      }

      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      print('🔴 [PRIVACY] Errore cambio password: $e');

      String errorMessage = 'Errore durante il cambio password';
      if (e.toString().contains('Password attuale non corretta')) {
        errorMessage = '❌ Password attuale non corretta';
      } else if (e.toString().contains('invalid')) {
        errorMessage = '❌ Password non valida';
      } else if (e.toString().contains('Utente non autenticato')) {
        errorMessage = '❌ Sessione scaduta. Effettua nuovamente il login.';
      } else {
        errorMessage = '❌ Errore: ${e.toString()}';
      }

      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Metodo per mostrare errori con dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Errore'),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
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
}

// ========================================
// BOTTOM SHEET: Change Email (Placeholder)
// ========================================
class _ChangeEmailSheet extends StatefulWidget {
  final String currentEmail;
  final VoidCallback onEmailChanged;

  const _ChangeEmailSheet({
    required this.currentEmail,
    required this.onEmailChanged,
  });

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _newEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _newEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Titolo
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Cambia Email',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Email attuale: ${widget.currentEmail}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),

                // Nuova Email
                TextFormField(
                  controller: _newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Nuova Email',
                    prefixIcon: const Icon(Icons.alternate_email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci la nuova email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Email non valida';
                    }
                    if (value == widget.currentEmail) {
                      return 'Questa è già la tua email attuale';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password di conferma
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password per conferma',
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
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Warning Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ti invieremo un\'email di conferma al nuovo indirizzo. Dovrai cliccare sul link per completare il cambio.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Pulsante Conferma
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleChangeEmail,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Cambia Email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleChangeEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user?.email == null) {
        throw Exception('Utente non autenticato');
      }

      // Verifica password
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: user!.email!,
          password: _passwordController.text,
        );
      } catch (e) {
        print('🔴 [PRIVACY] Errore verifica password: $e');
        throw Exception('Password non corretta');
      }

      // Aggiorna email
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            email: _newEmailController.text,
          ),
        );
      } catch (e) {
        print('🔴 [PRIVACY] Errore updateUser: $e');
        // Rilancia l'eccezione originale per gestirla sotto
        rethrow;
      }

      print('🟢 [PRIVACY] Email cambiata con successo');

      if (mounted) {
        Navigator.pop(context);
        
        // Mostra messaggio di successo più dettagliato
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '✅ Controlla la tua nuova email per confermare il cambio',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        
        widget.onEmailChanged();
      }
    } on AuthException catch (e) {
      // Gestione specifica errori Supabase Auth
      print('🔴 [PRIVACY] AuthException: ${e.message}');
      print('🔴 [PRIVACY] StatusCode: ${e.statusCode}');
      
      String errorMessage = 'Errore durante il cambio email';
      
      // Gestione errori specifici di Supabase
      if (e.message.contains('Email rate limit exceeded')) {
        errorMessage = '⚠️ Troppi tentativi. Riprova tra qualche minuto.';
      } else if (e.message.contains('already registered') || 
                 e.message.contains('already been registered') ||
                 e.message.contains('User already registered')) {
        errorMessage = '❌ Questa email è già registrata da un altro utente.\nScegli un\'altra email.';
      } else if (e.message.contains('Invalid email')) {
        errorMessage = '❌ Formato email non valido';
      } else if (e.statusCode == '422' || e.statusCode == '400') {
        // Codici di errore comuni per email duplicate
        errorMessage = '❌ Questa email è già in uso.\nProva con un\'altra email.';
      } else {
        // Mostra il messaggio di errore di Supabase
        errorMessage = '❌ ${e.message}';
      }

      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      print('🔴 [PRIVACY] Errore generico cambio email: $e');

      String errorMessage = 'Errore durante il cambio email';
      
      if (e.toString().contains('Password non corretta')) {
        errorMessage = '❌ Password non corretta';
      } else if (e.toString().contains('already registered') ||
                 e.toString().contains('already exists') ||
                 e.toString().contains('duplicate')) {
        errorMessage = '❌ Questa email è già registrata.\nProva con un\'altra email.';
      } else if (e.toString().contains('Utente non autenticato')) {
        errorMessage = '❌ Sessione scaduta. Effettua nuovamente il login.';
      } else {
        // Mostra l'errore completo all'utente per debugging
        errorMessage = '❌ Errore: ${e.toString()}';
      }

      if (mounted) {
        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Nuovo metodo per mostrare errori con dialog invece di solo snackbar
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Errore'),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
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
}