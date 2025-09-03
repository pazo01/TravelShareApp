import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/supabase_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializza Supabase
  await SupabaseConfig.initialize();
  
  runApp(
    const ProviderScope(
      child: TravelShareApp(),
    ),
  );
}