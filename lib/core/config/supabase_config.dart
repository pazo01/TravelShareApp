import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://shlvcymbathgqbhnikzj.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNobHZjeW1iYXRoZ3FiaG5pa3pqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY5MTc2NDAsImV4cCI6MjA3MjQ5MzY0MH0.XjrbhYYA4Yhp69ViuSEYHQsDo-iWySj9NTSGZPjsIN4';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}