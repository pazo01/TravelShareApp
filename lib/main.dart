import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/supabase_config.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cattura errori non gestiti (utile in debug)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  await runZonedGuarded<Future<void>>(() async {
    // 1) Carica ENV
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("[dotenv] Impossibile caricare .env: $e");
      // Proseguiamo comunque: l'app si avvia anche senza variabili (schermate UI).
    }

    // 2) Inizializza Supabase (se richiede chiavi da .env verrà gestito dentro)
    try {
      await SupabaseConfig.initialize();
    } catch (e, st) {
      debugPrint("[Supabase] init fallita: $e\n$st");
      // Non blocchiamo l'avvio della UI: potrai mostrare fallback/avvisi in app.
    }

    // 3) Avvia l’app con Riverpod come root
    runApp(
      const ProviderScope(
        child: TravelShareApp(),
      ),
    );
  }, (error, stack) {
    debugPrint("[Zoned] Uncaught error: $error\n$stack");
  });
}
