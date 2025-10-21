import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/payroll.dart';
import '../repositories/payroll_repository.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final repo = PayrollRepository();

  final _employeeId = TextEditingController(text: 'DEMO-EMPLOYEE-ID');
  final _periodYm =
      TextEditingController(text: DateFormat('yyyy-MM').format(DateTime.now()));

  final _baseSalary = TextEditingController(text: '2500000');
  final _allowance = TextEditingController(text: '300000');
  final _overtimeHours = TextEditingController(text: '0');
  final _overtimeRate = TextEditingController(text: '20000');
  final _lateMinutes = TextEditingController(text: '0');
  final _latePenaltyPerMin = TextEditingController(text: '500');
  final _otherDeductions = TextEditingController(text: '0');

  Map<String, double>? _result;
  bool _saving = false;

  double _toDouble(TextEditingController c, {double fallback = 0}) {
    return double.tryParse(c.text.replaceAll(',', '').trim()) ?? fallback;
  }

  int _toInt(TextEditingController c, {int fallback = 0}) {
    return int.tryParse(c.text.trim()) ?? fallback;
  }

  void _calculate() {
    final res = PayrollCalc.breakdown(
      baseSalary: _toDouble(_baseSalary),
      allowance: _toDouble(_allowance),
      overtimeHours: _toDouble(_overtimeHours),
      overtimeRate: _toDouble(_overtimeRate),
      lateMinutes: _toInt(_lateMinutes),
      latePenaltyPerMin: _toDouble(_latePenaltyPerMin),
      otherDeductions: _toDouble(_otherDeductions),
    );
    setState(() => _result = res);
  }

  Future<void> _save() async {
    if (_result == null) {
      _calculate();
      if (_result == null) return;
    }
    setState(() => _saving = true);
    try {
      await repo.insertPayroll(
        employeeId: _employeeId.text.trim(),
        periodYm: _periodYm.text.trim(),
        totalHours:
            _toDouble(_overtimeHours), // opsional: ganti total jam kerja
        overtimeHours: _toDouble(_overtimeHours),
        lateMinutes: _toInt(_lateMinutes),
        otherDeductions: _toDouble(_otherDeductions),
        totalPay: _result!['totalPay']!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payroll tersimpan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _numField(String label, TextEditingController c) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final res = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Hitung Payroll Bulanan')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            Row(children: [
              Expanded(child: _numField('Employee ID', _employeeId)),
              const SizedBox(width: 8),
              Expanded(child: _numField('Periode (YYYY-MM)', _periodYm)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _numField('Gaji Pokok', _baseSalary)),
              const SizedBox(width: 8),
              Expanded(child: _numField('Tunjangan', _allowance)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _numField('Lembur (jam)', _overtimeHours)),
              const SizedBox(width: 8),
              Expanded(child: _numField('Tarif Lembur/jam', _overtimeRate)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _numField('Terlambat (menit)', _lateMinutes)),
              const SizedBox(width: 8),
              Expanded(child: _numField('Denda/menit', _latePenaltyPerMin)),
            ]),
            const SizedBox(height: 12),
            _numField('Potongan lain', _otherDeductions),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Hitung'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(_saving ? 'Menyimpan…' : 'Simpan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (res != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Rincian',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                          'Gaji Pokok : ${res['baseSalary']!.toStringAsFixed(0)}'),
                      Text(
                          'Tunjangan  : ${res['allowance']!.toStringAsFixed(0)}'),
                      Text(
                          'Lembur     : ${res['overtimePay']!.toStringAsFixed(0)}'),
                      Text(
                          'Denda Telat: -${res['latePenalty']!.toStringAsFixed(0)}'),
                      Text(
                          'Potongan   : -${res['otherDeductions']!.toStringAsFixed(0)}'),
                      const Divider(),
                      Text(
                          'Total      : ${res['totalPay']!.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
