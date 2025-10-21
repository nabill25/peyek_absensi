import 'package:flutter/material.dart';
import 'supabase_client.dart';
import 'screens/home_screen.dart';
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSupabase.init(); // init Supabase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Absensi Peyek',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const AuthGate(),
    );
  }
}
