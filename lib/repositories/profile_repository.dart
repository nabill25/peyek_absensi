import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final _client = Supabase.instance.client;

  /// Pastikan baris profil milik user ada. Jika belum, buat.
  Future<void> ensureMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Belum login');

    final check = await _client
        .from('profiles')
        .select() // tanpa generic -> aman utk supabase_dart v2
        .eq('id', user.id)
        .maybeSingle();

    if (check != null) return;

    final defaultEmployeeId = 'EMP-${user.id.substring(0, 8).toUpperCase()}';
    final email = user.email ?? '';
    final defaultFullName = email.contains('@')
        ? email.split('@').first
        : (email.isEmpty ? 'User' : email);

    await _client.from('profiles').upsert(
      {
        'id': user.id,
        'employee_id': defaultEmployeeId,
        'full_name': defaultFullName,
      },
      onConflict: 'id',
    );
  }

  /// Ambil employee_id milik user saat ini. Null jika belum ada/empty.
  Future<String?> getMyEmployeeId() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Belum login');

    final row = await Supabase.instance.client
        .from('profiles')
        .select('employee_id')
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;
    final value = row['employee_id'];
    return (value is String && value.trim().isNotEmpty) ? value : null;
  }

  /// Ambil profil saya (full_name & employee_id).
  Future<Map<String, dynamic>> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Belum login');

    final row = await _client
        .from('profiles')
        .select('full_name, employee_id')
        .eq('id', user.id)
        .single();

    return {
      'email': user.email,
      'full_name': row['full_name'],
      'employee_id': row['employee_id'],
    };
  }

  /// Update profil saya.
  Future<void> updateMyProfile({
    required String fullName,
    required String employeeId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Belum login');

    await _client.from('profiles').update({
      'full_name': fullName,
      'employee_id': employeeId,
    }).eq('id', user.id);
  }
}

Future<Map<String, dynamic>?> getMyProfile() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw Exception('Belum login');

  final row = await Supabase.instance.client
      .from('profiles')
      .select('full_name, employee_id')
      .eq('id', user.id)
      .maybeSingle();

  return row; // bisa null kalau belum ada
}

Future<void> updateMyProfile({
  required String fullName,
  required String employeeId,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw Exception('Belum login');

  ensureMyProfile() {}

  // pastikan baris profil ada
  ensureMyProfile();

  await Supabase.instance.client.from('profiles').update({
    'full_name': fullName.trim(),
    'employee_id': employeeId.trim(),
  }).eq('id', user.id);
}
