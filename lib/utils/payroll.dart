class PayrollCalc {
  /// Hitung total gaji bulanan sederhana.
  static double total({
    required double baseSalary,
    required double allowance,
    required double overtimeHours,
    required double overtimeRate,
    required int lateMinutes,
    required double latePenaltyPerMin,
    double otherDeductions = 0,
  }) {
    final overtimePay = overtimeHours * overtimeRate;
    final latePenalty = lateMinutes * latePenaltyPerMin;
    return baseSalary + allowance + overtimePay - latePenalty - otherDeductions;
  }

  /// Detail per komponen (opsional untuk ditampilkan di UI).
  static Map<String, double> breakdown({
    required double baseSalary,
    required double allowance,
    required double overtimeHours,
    required double overtimeRate,
    required int lateMinutes,
    required double latePenaltyPerMin,
    double otherDeductions = 0,
  }) {
    final overtimePay = overtimeHours * overtimeRate;
    final latePenalty = lateMinutes * latePenaltyPerMin;
    final totalPay =
        baseSalary + allowance + overtimePay - latePenalty - otherDeductions;

    return {
      'baseSalary': baseSalary,
      'allowance': allowance,
      'overtimePay': overtimePay,
      'latePenalty': latePenalty,
      'otherDeductions': otherDeductions,
      'totalPay': totalPay,
    };
  }
}
