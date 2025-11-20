import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../../core/config/supabase_config.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Sessione utente corrente
  static Session? get currentSession => _supabase.auth.currentSession;
  static User? get currentUser => _supabase.auth.currentUser;

  /// Stream per ascoltare i cambiamenti dello stato di autenticazione
  static Stream<AuthState> get authStateStream =>
      _supabase.auth.onAuthStateChange;

  /// Controlla se l'utente Ã¨ autenticato
  static bool get isAuthenticated => currentSession != null;

  /// 1. AUTENTICAZIONE GOOGLE - MIGLIORATA CON RETRY
  static Future<AuthResponse> signInWithGoogle() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '57199450253-8144397hpp8a68lis9assv013jsvaqdc.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
          .authenticate();

      if (googleUser == null) {
        throw Exception('Login con Google annullato dall\'utente.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception(
          'ID Token non trovato. Verifica la configurazione OAuth.',
        );
      }

      // Prima prova
      try {
        final response = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
        );

        if (response.user != null) {
          await _createOrUpdateProfile(response.user!);
        }

        return response;
      } catch (e) {
        // Se fallisce con errore 400, riprova dopo un breve delay
        if (e.toString().contains('400') || e.toString().contains('Internal Server Error')) {
          print('âš ï¸ Primo tentativo fallito, riprovo...');
          await Future.delayed(const Duration(seconds: 1));
          
          // Secondo tentativo
          final response = await _supabase.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
          );

          if (response.user != null) {
            await _createOrUpdateProfile(response.user!);
          }

          return response;
        }
        rethrow;
      }
    } catch (e) {
      print('ðŸ”´ Errore Google Sign-In: $e');
      rethrow;
    }
  }

  /// 2. AUTENTICAZIONE EMAIL
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        await _createOrUpdateProfile(response.user!);
      }
      return response;
    } catch (e) {
      throw Exception('Accesso con email fallito: $e');
    }
  }

  /// 3. REGISTRAZIONE EMAIL CON OTP - L'utente deve verificare l'email prima di poter accedere
  static Future<void> signUpWithEmailOtp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Invia OTP per registrazione - Supabase invia automaticamente l'email
      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null, // Non serve redirect, usiamo solo OTP
        data: {
          'full_name': fullName,
          'password': password, // Salviamo temporaneamente nei metadata
        },
      );
      
      print('âœ… OTP inviato a $email');
    } catch (e) {
      print('ðŸ”´ Errore invio OTP: $e');
      throw Exception('Errore durante l\'invio del codice di verifica: $e');
    }
  }

  /// 3b. VERIFICA OTP EMAIL - Completa la registrazione dopo verifica
  static Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      // Verifica l'OTP
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

      if (response.user != null) {
        // Recupera i dati temporanei
        final fullName = response.user!.userMetadata?['full_name'];
        final password = response.user!.userMetadata?['password'];

        // Se c'Ã¨ una password nei metadata, aggiorna l'utente con la password definitiva
        if (password != null) {
          try {
            await _supabase.auth.updateUser(
              UserAttributes(
                password: password,
              ),
            );
          } catch (e) {
            print('âš ï¸ Errore aggiornamento password: $e');
          }
        }

        // Crea il profilo
        await _createOrUpdateProfile(response.user!);
        
        // Fai logout per far accedere l'utente con email e password
        await _supabase.auth.signOut();
      }

      return response;
    } catch (e) {
      print('ðŸ”´ Errore verifica OTP: $e');
      throw Exception('Codice non valido o scaduto: $e');
    }
  }

  /// 3c. REINVIA OTP EMAIL
  static Future<void> resendEmailOtp({required String email}) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: null,
      );
      print('âœ… Nuovo OTP inviato a $email');
    } catch (e) {
      print('ðŸ”´ Errore reinvio OTP: $e');
      throw Exception('Errore durante il reinvio del codice: $e');
    }
  }

  /// 4. AUTENTICAZIONE SMS
  static Future<void> signInWithPhone(String phoneNumber) async {
    try {
      await _supabase.auth.signInWithOtp(phone: phoneNumber);
    } catch (e) {
      throw Exception('Accesso con SMS fallito: $e');
    }
  }

  /// 5. VERIFICA OTP
  static Future<AuthResponse> verifyOTP({
    required String token,
    required OtpType type,
    String? email,
    String? phone,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        token: token,
        type: type,
        email: email,
        phone: phone,
      );
      if (response.user != null) {
        await _createOrUpdateProfile(response.user!);
      }
      return response;
    } catch (e) {
      throw Exception('Verifica OTP fallita: $e');
    }
  }

  /// 6. RIMUOVI TELEFONO - NUOVA FUNZIONE
  static Future<Map<String, dynamic>> removeUserPhone() async {
    try {
      print('ðŸ”µ [AUTH_SERVICE] Chiamata RPC remove_user_phone...');
      
      final response = await _supabase.rpc('remove_user_phone').single();
      
      print('âœ… [AUTH_SERVICE] RPC Response: $response');
      
      // Cast sicuro della risposta
      if (response is Map<String, dynamic>) {
        return response;
      } else {
        return {
          'success': false,
          'message': 'Risposta non valida dal server'
        };
      }
    } catch (e) {
      print('ðŸ”´ [AUTH_SERVICE] Errore RPC: $e');
      
      // Gestione errori specifici
      if (e.toString().contains('500') || e.toString().contains('unexpected_failure')) {
        return {
          'success': false,
          'message': 'Errore del server. L\'account potrebbe essere in uno stato inconsistente. Prova a fare logout e riaccedere.',
          'error': e.toString()
        };
      } else if (e.toString().contains('permission')) {
        return {
          'success': false,
          'message': 'Non hai i permessi per questa operazione.',
          'error': e.toString()
        };
      } else if (e.toString().contains('function') || e.toString().contains('not found')) {
        return {
          'success': false,
          'message': 'Funzione non trovata sul server. Contatta il supporto.',
          'error': e.toString()
        };
      }
      
      return {
        'success': false,
        'message': 'Si Ã¨ verificato un errore durante la rimozione del telefono',
        'error': e.toString()
      };
    }
  }

  /// 7. RECUPERO PASSWORD - Invia email con link di reset
  static Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: SupabaseConfig.redirectUrl,
      );
    } catch (e) {
      throw Exception('Recupero password fallito: $e');
    }
  }

  /// 8. AGGIORNA PASSWORD - Dopo aver cliccato sul link
  static Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception('Aggiornamento password fallito: $e');
    }
  }

  /// 9. SIGN OUT - MIGLIORATO CON FALLBACK
  static Future<void> signOut() async {
    try {
      // Prima disconnetti Google
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        print('âš ï¸ Errore disconnessione Google (ignorato): $e');
      }
      
      // Poi disconnetti Supabase
      await _supabase.auth.signOut();
      print('âœ… Sign out completato');
    } catch (e) {
      print('ðŸ”´ Errore Sign Out: $e');
      
      // Se il logout normale fallisce (errore 500), prova il logout locale
      if (e.toString().contains('500') || e.toString().contains('unexpected_failure')) {
        try {
          print('âš ï¸ Tentativo logout locale...');
          await _supabase.auth.signOut(scope: SignOutScope.local);
          print('âœ… Logout locale completato');
        } catch (localError) {
          print('ðŸ”´ Anche il logout locale ha fallito: $localError');
          // Non rilanciare l'errore per permettere la navigazione
          print('âš ï¸ Continuo comunque con la pulizia locale');
        }
      } else {
        throw Exception('Sign out fallito: $e');
      }
    }
  }

  /// NUOVO: Controlla se una email esiste giÃ 
  static Future<bool> checkEmailExists({required String email}) async {
    try {
      final bool exists = await _supabase.rpc(
        'check_email_exists',
        params: {'user_email': email},
      );
      return exists;
    } catch (e) {
      print('ðŸ”´ Errore controllo email: $e');
      // Se la chiamata RPC fallisce (es. funzione non trovata), 
      // restituisce false per permettere a Supabase di gestire 
      // l'errore di duplicato (che Ã¨ piÃ¹ sicuro).
      return false; 
    }
  }


  /// Helper: Crea o aggiorna il profilo utente
  /// --- CORRETTO: Non sovrascrive campi personalizzabili ---
  static Future<void> _createOrUpdateProfile(User user) async {
    try {
      final existingProfile = await _supabase
          .from('user_profiles')
          .select('id, full_name, bio, languages')
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        // --- NUOVO UTENTE ---
        final profileData = {
          'id': user.id,
          'email': user.email,
          'phone': user.phone,
          'full_name': user.userMetadata?['full_name'] ?? user.email?.split('@').first,
          'google_id': user.userMetadata?['provider_id'],
          'avatar_url': user.userMetadata?['avatar_url'],
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        print('🆕 [AUTH] Nuovo utente, creo profilo: ${user.id}');
        await _supabase.from('user_profiles').insert(profileData);
        
      } else {
        // --- UTENTE ESISTENTE ---
        // Aggiorniamo SOLO email e phone
        // NON tocchiamo: full_name, bio, languages, avatar_url
        final updateData = {
          'email': user.email,
          'phone': user.phone,
          'google_id': user.userMetadata?['provider_id'],
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        print('🔵 [AUTH] Utente esistente, aggiorno SOLO dati auth: ${user.id}');
        print('   ℹ️  Nome, bio, lingue e foto NON verranno modificati');
        await _supabase
            .from('user_profiles')
            .update(updateData)
            .eq('id', user.id);
      }
    } catch (e) {
      print('🔴 Errore durante la creazione/aggiornamento del profilo: $e');
    }
  }

  /// Ottieni profilo utente
  static Future<UserProfile?> getUserProfile() async {
    if (!isAuthenticated) return null;
    try {
      final response = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      return UserProfile.fromJson(response);
    } catch (e) {
      print('Errore nel recupero del profilo utente: $e');
      return null;
    }
  }

  /// NUOVA: Verifica lo stato dell'account
  static Future<bool> checkAccountHealth() async {
    try {
      final user = currentUser;
      if (user == null) return false;
      
      // Verifica che abbia almeno un metodo di autenticazione
      final hasEmail = user.email != null && user.email!.isNotEmpty;
      final hasPhone = user.phone != null && user.phone!.isNotEmpty;
      
      if (!hasEmail && !hasPhone) {
        print('âš ï¸ Account senza metodi di autenticazione!');
        return false;
      }
      
      // Verifica le identities
      if (user.identities == null || user.identities!.isEmpty) {
        print('âš ï¸ Account senza identities!');
        return false;
      }
      
      return true;
    } catch (e) {
      print('ðŸ”´ Errore verifica stato account: $e');
      return false;
    }
  }
}