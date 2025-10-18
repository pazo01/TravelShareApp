import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Sessione utente corrente
  static Session? get currentSession => _supabase.auth.currentSession;
  static User? get currentUser => _supabase.auth.currentUser;

  /// Stream per ascoltare i cambiamenti dello stato di autenticazione
  static Stream<AuthState> get authStateStream =>
      _supabase.auth.onAuthStateChange;

  /// Controlla se l'utente è autenticato
  static bool get isAuthenticated => currentSession != null;

  /// 1. AUTENTICAZIONE GOOGLE
  static Future<AuthResponse> signInWithGoogle() async {
    try {
      // STEP 1: Inizializza GoogleSignIn
      await GoogleSignIn.instance.initialize(
        // TODO: Sostituisci con il tuo WEB Client ID
        serverClientId:
            '57199450253-8144397hpp8a68lis9assv013jsvaqdc.apps.googleusercontent.com',
      );

      // STEP 2: Avvia il processo di login
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
          .authenticate();

      if (googleUser == null) {
        throw Exception('Login con Google annullato dall\'utente.');
      }

      // STEP 3: Ottieni i token di autenticazione
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception(
          'ID Token non trovato. Verifica la configurazione OAuth.',
        );
      }

      // STEP 4: Autentica con Supabase
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      // STEP 5: Crea/aggiorna il profilo utente
      if (response.user != null) {
        await _createOrUpdateProfile(response.user!);
      }

      return response;
    } catch (e) {
      print('🔴 Errore Google Sign-In: $e');
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

  /// 3. REGISTRAZIONE EMAIL
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

  /// 6. RECUPERO PASSWORD
  static Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Recupero password fallito: $e');
    }
  }

  /// 7. SIGN OUT
  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      await _supabase.auth.signOut();
    } catch (e) {
      print('🔴 Errore Sign Out: $e');
      throw Exception('Sign out fallito: $e');
    }
  }

  /// Helper: Crea o aggiorna il profilo utente
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
}
