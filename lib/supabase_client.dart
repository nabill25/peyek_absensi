import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabase {
  static const String url = 'https://efbhvpbpfdkmfdqtssdc.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVmYmh2cGJwZmRrbWZkcXRzc2RjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA1OTYzNzgsImV4cCI6MjA3NjE3MjM3OH0.POUoVbFEiYchKIZgrOKyoMGFaUWnVDpXPqpfsRvPGF8';

  static Future<void> init() async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
