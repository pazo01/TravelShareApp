import 'package:supabase_flutter/supabase_flutter.dart';

/// Servizio per gestire l'autenticazione a due fattori (2FA)
class MfaService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Verifica se il 2FA è abilitato per l'utente corrente
  static Future<bool> isMfaEnabled() async {
    try {
      final factors = await _supabase.auth.mfa.listFactors();
      
      // Verifica se c'è almeno un fattore TOTP verificato
      final totpFactors = factors.totp;
      if (totpFactors == null || totpFactors.isEmpty) {
        return false;
      }
      
      return totpFactors.any((factor) => factor.status == FactorStatus.verified);
    } catch (e) {
      print('🔴 Errore verifica stato 2FA: $e');
      return false;
    }
  }

  /// Rimuove tutti i fattori non verificati (pulizia)
  /// Utile quando l'utente abbandona la registrazione 2FA senza completarla
  static Future<void> cleanupUnverifiedFactors() async {
    try {
      print('🧹 Pulizia fattori non verificati...');
      
      final factors = await _supabase.auth.mfa.listFactors();
      final totpFactors = factors.totp;
      
      if (totpFactors == null || totpFactors.isEmpty) {
        print('✅ Nessun fattore da pulire');
        return;
      }
      
      int removedCount = 0;
      int verifiedCount = 0;
      
      for (final factor in totpFactors) {
        print('📋 Fattore trovato: ${factor.id} - Status: ${factor.status}');
        
        // --- !!! MODIFICA CORRETTA QUI !!! ---
        // Confronta l'enum con l'enum, non con una stringa
        if (factor.status == FactorStatus.verified) {
        // --- !!! FINE MODIFICA !!! ---
          verifiedCount++;
          print('✓ Fattore verificato, lo mantengo: ${factor.id}');
        } else {
          try {
            await _supabase.auth.mfa.unenroll(factor.id);
            removedCount++;
            print('✅ Fattore non verificato rimosso: ${factor.id}');
          } catch (e) {
            print('⚠️ Errore rimozione fattore ${factor.id}: $e');
          }
        }
      }
      
      print('✅ Pulizia completata: $removedCount rimossi, $verifiedCount verificati mantenuti');
    } catch (e) {
      print('🔴 Errore durante la pulizia: $e');
      // Non rilanciare l'eccezione - è solo una pulizia
    }
  }

  /// Avvia il processo di registrazione del 2FA
  /// Prima pulisce eventuali fattori non verificati
  /// Restituisce le informazioni necessarie per generare il QR code
  static Future<AuthMFAEnrollResponse> enrollMfa() async {
    try {
      print('🔐 Avvio registrazione 2FA...');
      
      // Verifica se c'è già un fattore verificato attivo
      final isEnabled = await isMfaEnabled();
      if (isEnabled) {
        print('⚠️ 2FA già attivo, non posso crearne un altro');
        throw Exception('2FA già attivo per questo account');
      }
      
      // Prima pulisci eventuali fattori non verificati rimasti
      await cleanupUnverifiedFactors();
      
      final response = await _supabase.auth.mfa.enroll(
        issuer: 'TravelShare', // Nome dell'app che apparirà nell'authenticator
        friendlyName: 'TravelShare Account',
      );

      print('✅ 2FA registrato con ID: ${response.id}');
      return response;
    } on AuthApiException catch (e) {
      print('🔴 AuthApiException during registrazione 2FA: ${e.message}');
      if (e.message.contains('already exists') || e.code == 'mfa_factor_name_conflict') {
        throw Exception('Hai già un 2FA attivo. Disattivalo prima per configurarne uno nuovo.');
      }
      rethrow;
    } catch (e) {
      print('🔴 Errore durante la registrazione 2FA: $e');
      rethrow;
    }
  }

  /// Verifica il codice TOTP e completa la registrazione del 2FA
  static Future<AuthMFAVerifyResponse> verifyMfaEnrollment({
    required String factorId,
    required String code,
  }) async {
    try {
      print('🔐 Verifica codice 2FA per factor: $factorId');
      
      final challenge = await _supabase.auth.mfa.challenge(
        factorId: factorId,
      );

      final response = await _supabase.auth.mfa.verify(
        factorId: factorId,
        challengeId: challenge.id,
        code: code,
      );

      print('✅ Codice 2FA verificato con successo!');
      return response;
    } catch (e) {
      print('🔴 Errore durante la verifica del codice 2FA: $e');
      
      if (e.toString().contains('Invalid TOTP code')) {
        throw Exception('Codice non valido. Riprova.');
      } else if (e.toString().contains('expired')) {
        throw Exception('Codice scaduto. Riprova.');
      }
      
      throw Exception('Errore during la verifica: ${e.toString()}');
    }
  }

  /// Disabilita il 2FA (rimuove tutti i fattori)
  static Future<void> disableMfa() async {
    try {
      print('🔐 Disabilitazione 2FA...');
      
      final factors = await _supabase.auth.mfa.listFactors();
      
      // Rimuovi tutti i fattori TOTP
      final totpFactors = factors.totp;
      if (totpFactors != null) {
        for (final factor in totpFactors) {
          await _supabase.auth.mfa.unenroll(factor.id);
          print('✅ Fattore ${factor.id} rimosso');
        }
      }
      
      print('✅ 2FA disabilitato completamente');
    } catch (e) {
      print('🔴 Errore during la disabilitazione 2FA: $e');
      rethrow;
    }
  }

  /// Ottiene tutti i fattori MFA registrati
  static Future<AuthMFAListFactorsResponse> getFactors() async {
    try {
      return await _supabase.auth.mfa.listFactors();
    } catch (e) {
      print('🔴 Errore recupero fattori 2FA: $e');
      rethrow;
    }
  }

  /// Crea una challenge per la verifica during il login
  static Future<AuthMFAChallengeResponse> createChallenge(String factorId) async {
    try {
      print('🔐 Creazione challenge per factor: $factorId');
      
      final challenge = await _supabase.auth.mfa.challenge(
        factorId: factorId,
      );
      
      print('✅ Challenge creata: ${challenge.id}');
      return challenge;
    } catch (e) {
      print('🔴 Errore creazione challenge: $e');
      rethrow;
    }
  }

  /// Verifica il codice TOTP during il login
  static Future<AuthMFAVerifyResponse> verifyMfaCode({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    try {
      print('🔐 Verifica codice 2FA during login...');
      
      final response = await _supabase.auth.mfa.verify(
        factorId: factorId,
        challengeId: challengeId,
        code: code,
      );
      
      print('✅ Login 2FA completato con successo!');
      return response;
    } catch (e) {
      print('🔴 Errore verifica codice 2FA during login: $e');
      
      if (e.toString().contains('Invalid TOTP code')) {
        throw Exception('Codice non valido');
      } else if (e.toString().contains('expired')) {
        throw Exception('Codice scaduto');
      }
      
      throw Exception('Errore during la verifica');
    }
  }

  /// Genera un URI per il QR code che può essere scansionato da un'app authenticator
  static String generateQrCodeUri({
    required String secret,
    required String email,
  }) {
    // Formato standard per TOTP: otpauth://totp/ISSUER:ACCOUNT?secret=SECRET&issuer=ISSUER
    final account = Uri.encodeComponent(email);
    final issuer = Uri.encodeComponent('TravelShare');
    
    return 'otpauth://totp/$issuer:$account?secret=$secret&issuer=$issuer&algorithm=SHA1&digits=6&period=30';
  }

  /// Rimuove un singolo fattore specificato (es. annullando l'enrollment)
  static Future<void> unenrollFactor(String factorId) async {
    try {
      print('🧹 Rimozione fattore specifico: $factorId');
      await _supabase.auth.mfa.unenroll(factorId);
      print('✅ Fattore rimosso: $factorId');
    } catch (e) {
      print('🔴 Errore rimozione fattore $factorId: $e');
      // Non rilanciare l'eccezione - è solo una pulizia
    }
  }
}