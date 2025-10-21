import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';

class PayrollRepository {
  final SupabaseClient _db = AppSupabase.client;

  /// Simpan / tambah payroll bulanan.
  Future<void> insertPayroll({
    required String employeeId, // contoh: 'DEMO-EMPLOYEE-ID'
    required String periodYm, // format: '2025-10'
    required double totalHours,
    required double overtimeHours,
    required int lateMinutes,
    double otherDeductions = 0,
    required double totalPay,
  }) async {
    await _db.from('payroll').insert({
      'employee_id': employeeId,
      'period_ym': periodYm,
      'total_hours': totalHours,
      'overtime_hours': overtimeHours,
      'late_minutes': lateMinutes,
      'other_deductions': otherDeductions,
      'total_pay': totalPay,
    });
  }

  /// Ambil daftar payroll terbaru (opsional filter per karyawan).
  Future<List<Map<String, dynamic>>> fetchRecentPayroll({
    String? employeeId,
    int limit = 50,
  }) async {
    if (employeeId != null && employeeId.isNotEmpty) {
      final rows = await _db
          .from('payroll')
          .select()
          .eq('employee_id', employeeId)
          .order('generated_at', ascending: false)
          .limit(limit);
      return rows.cast<Map<String, dynamic>>();
    } else {
      final rows = await _db
          .from('payroll')
          .select()
          .order('generated_at', ascending: false)
          .limit(limit);
      return rows.cast<Map<String, dynamic>>();
    }
  }

  /// Ambil payroll untuk periode tertentu.
  Future<List<Map<String, dynamic>>> findByPeriod({
    required String periodYm, // 'YYYY-MM'
    String? employeeId,
  }) async {
    if (employeeId != null && employeeId.isNotEmpty) {
      final rows = await _db
          .from('payroll')
          .select()
          .eq('period_ym', periodYm)
          .eq('employee_id', employeeId);
      return rows.cast<Map<String, dynamic>>();
    } else {
      final rows = await _db.from('payroll').select().eq('period_ym', periodYm);
      return rows.cast<Map<String, dynamic>>();
    }
  }
}
