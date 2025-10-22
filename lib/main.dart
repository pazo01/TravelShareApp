import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'app.dart';
import 'presentation/screens/reset_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializza Supabase
  await SupabaseConfig.initialize();
  
  // 🔗 Listener per Deep Link (recupero password)
  _setupDeepLinkListener();
  
  runApp(
    const ProviderScope(
      child: TravelShareApp(),
    ),
  );
}

void _setupDeepLinkListener() {
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    
    // 🔐 Quando Supabase rileva un evento di password recovery
    if (event == AuthChangeEvent.passwordRecovery) {
      print('✅ Deep Link ricevuto: Password Recovery');
      
      // Naviga alla schermata di reset password
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ResetPasswordScreen(),
          ),
        );
      }
    }
  });
}

// GlobalKey per la navigazione da fuori del contesto widget
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();