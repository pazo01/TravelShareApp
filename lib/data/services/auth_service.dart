import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart'; // Assicurati che il percorso del modello sia corretto

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // NUOVO METODO: Non si passa più il Client ID qui.
  // Si usa l'istanza globale fornita dal pacchetto.
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  /// Sessione utente corrente
  static Session? get currentSession => _supabase.auth.currentSession;
  static User? get currentUser => _supabase.auth.currentUser;

  /// Stream per ascoltare i cambiamenti dello stato di autenticazione
  static Stream<AuthState> get authStateStream =>
      _supabase.auth.onAuthStateChange;

  /// Controlla se l'utente è autenticato
  static bool get isAuthenticated => currentSession != null;

  /// 1. AUTENTICAZIONE GOOGLE (CODICE COMPLETAMENTE CORRETTO)
  static Future<AuthResponse> signInWithGoogle() async {
    try {
      // NUOVO METODO: La funzione per avviare il login ora è .authenticate()
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();

      // Se l'utente chiude la finestra di login, googleUser sarà null
      if (googleUser == null) {
        throw Exception('Login con Google annullato dall\'utente.');
      }

      // Ottieni i token di autenticazione
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final idToken = googleAuth.idToken;

      // L'accessToken non è più disponibile in questo oggetto e non serve a Supabase
      if (idToken == null) {
        throw Exception(
          'ID Token non trovato. Assicurati che la configurazione OAuth sia corretta.',
        );
      }

      // Esegui l'accesso a Supabase usando SOLO l'idToken.
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.user != null) {
        await _createOrUpdateProfile(response.user!);
      }

      return response;
    } catch (e) {
      // Stampiamo l'errore per un debug più facile in futuro
      print('Errore dettagliato durante il login con Google: $e');
      throw Exception('Login con Google fallito.');
    }
  }

  /// 2. AUTENTICAZIONE EMAIL (INVARIATO)
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

  /// 3. REGISTRAZIONE EMAIL (INVARIATO)
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      return response;
    } catch (e) {
      throw Exception('Registrazione con email fallita: $e');
    }
  }

  /// 4. AUTENTICAZIONE SMS (INVARIATO)
  static Future<void> signInWithPhone(String phoneNumber) async {
    try {
      await _supabase.auth.signInWithOtp(phone: phoneNumber);
    } catch (e) {
      throw Exception('Accesso con SMS fallito: $e');
    }
  }

  /// 5. VERIFICA OTP (INVARIATO)
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

  /// 6. RECUPERO PASSWORD (INVARIATO)
  static Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Recupero password fallito: $e');
    }
  }

  /// 7. SIGN OUT (CODICE CORRETTO)
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Sign out fallito: $e');
    }
  }

  /// Helper: Crea o aggiorna il profilo utente (INVARIATO)
  static Future<void> _createOrUpdateProfile(User user) async {
    try {
      final existingProfile = await _supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final profileData = {
        'id': user.id,
        'email': user.email,
        'phone': user.phone,
        'full_name':
            user.userMetadata?['full_name'] ?? user.email?.split('@').first,
        'avatar_url': user.userMetadata?['avatar_url'],
        'google_id': user.userMetadata?['provider_id'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingProfile == null) {
        await _supabase.from('user_profiles').insert(profileData);
      } else {
        await _supabase
            .from('user_profiles')
            .update(profileData)
            .eq('id', user.id);
      }
    } catch (e) {
      print('Errore durante la creazione/aggiornamento del profilo: $e');
    }
  }

  /// Ottieni profilo utente (INVARIATO)
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
}
