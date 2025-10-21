import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    // Bangun UI awal dari sesi saat ini, lalu dengarkan perubahan
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;

        // Jika ada session -> masuk ke Home, kalau belum -> ke Login
        if (session != null && session.user != null) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
