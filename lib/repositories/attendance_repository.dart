import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class AttendanceRepository {
  final SupabaseClient _db = AppSupabase.client;

  /// Ambil 1 baris konfigurasi settings (pusat geofence).
  Future<Map<String, dynamic>?> loadSettings() async {
    final rows = await _db.from('settings').select().limit(1);
    if (rows.isEmpty) return null;

    final m = rows.first as Map<String, dynamic>;
    return {
      'store_name': m['store_name'],
      'center_lat': (m['center_lat'] as num).toDouble(),
      'center_lng': (m['center_lng'] as num).toDouble(),
      'radius_m': (m['radius_m'] as num).toDouble(),
      'accuracy_threshold_m': (m['accuracy_threshold_m'] as num).toDouble(),
    };
  }

  /// Simpan catatan absensi.
  Future<void> insertAttendance({
    required String employeeId,
    required String kind, // 'IN' atau 'OUT'
    required double lat,
    required double lng,
    required double accuracyM,
    required double distanceM,
    bool isMock = false,
    String? note,
  }) async {
    await _db.from('attendance').insert({
      'employee_id': employeeId,
      'kind': kind,
      'lat': lat,
      'lng': lng,
      'accuracy_m': accuracyM,
      'distance_m': distanceM,
      'is_mock': isMock,
      'note': note,
    });
  }

  /// Ambil riwayat absensi terbaru (opsional filter per karyawan).
  Future<List<Map<String, dynamic>>> fetchRecentAttendance({
    String? employeeId,
    int limit = 50,
  }) async {
    if (employeeId != null && employeeId.isNotEmpty) {
      final rows = await _db
          .from('attendance')
          .select()
          .eq('employee_id', employeeId)
          .order('ts', ascending: false)
          .limit(limit);
      return rows.cast<Map<String, dynamic>>();
    } else {
      final rows = await _db
          .from('attendance')
          .select()
          .order('ts', ascending: false)
          .limit(limit);
      return rows.cast<Map<String, dynamic>>();
    }
  }
}
